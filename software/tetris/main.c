// main.c: Tetris
//
// Copyright (C) 2020 mara <vmedea@protonmail.com>
// based on tetris4terminals by fnh <hendrich@informatik.uni-hamburg.de>, adapted by emard <vordah@gmail.com>
// SPDX-License-Identifier: MIT

// Basic tetris game, demonstrates:
// - use of sprites over tile map combining text and custom tiles
// - use of different palettes, simple palette animation
// - use of gamepad edge triggered actions
// - unpredictability by seeding a random generator with keypress time

#include <stdint.h>
#include <stdbool.h>

#include "audio.h"
#include "vdp.h"
#include "font.h"
#include "gamepad.h"
#include "rand.h"

#include "shortbeep.h"
#include "longbeep.h"

// screen and timing
// cannot use the constant here due to gcc error "error: initializer element is not constant"
static const uint16_t TILES_W = /* SCREEN_ACTIVE_WIDTH */ 848 / 8;
static const uint16_t TILES_H = /* SCREEN_ACTIVE_HEIGHT */ 480 / 8;
static const uint32_t FRAME_MS = 17;
static const uint16_t TILE_VRAM_BASE = 0x0000;
static const uint16_t MAP_VRAM_BASE = 0x4000;

// max level
//  9: (default), 0.1s delay between steps
// 10: impossible, no delay between steps
static const uint8_t MAX_level = 9;

// number of different block shapes (changing this will require quite a few
// other changes throughout the game)
static const uint8_t NUM_SHAPES = 7;

// starts game with step 1 s at level 1, it's a longest step time
static const uint32_t MS_STEP_START = 1000;
#define STEP_FASTER(x) x*3/4

// board definitions
#define ROWS 24  // height of board
#define COLS 10  // width of board

static const uint8_t ROWSD = 23; // last N rows of active gamefield displayed
#define ROW0  (ROWS - ROWSD) // first row displayed
static const uint8_t ROWNEW = 0; // ROW in memory where new piece appears
static const uint8_t COLNEW = 3; // COL in memory where new piece appears

// screen position of board
static const uint16_t BOARD_X = TILES_W / 2 - (COLS + 20) / 2;
static const uint16_t BOARD_Y = TILES_H / 2 - ROWS / 2;

// screen position of score and level indicators
static const uint16_t INFO_X = BOARD_X + COLS + 5;
static const uint16_t INFO_Y = BOARD_Y + ROWS / 2 + 1;

// current game state (bitfield)
enum game_state {
    PLAYING,
    TIMEOUT,
    GAME_OVER,
    BEGINNING,
    PAUSED,
};

// game actions
enum game_cmd {
    CMD_NONE,
    CMD_LEFT,
    CMD_RIGHT,
    CMD_ROTATE_CCW,
    CMD_ROTATE_CW,
    CMD_DROP,
    CMD_START,
};

// game sounds
enum game_sound {
    SND_SHORTBEEP = 0, // https://freesound.org/people/solernix/sounds/540902/
    SND_LONGBEEP = 1,  // https://freesound.org/people/pan14/sounds/263133/
};

static const int16_t *const SAMPLE_POINTERS[] = {shortbeep, longbeep};
static const size_t *const SAMPLE_LENGTHS[] = {&shortbeep_length, &longbeep_length};
const int8_t VOLUME = 0x0c;
const int16_t PITCH = 0x1000; // neutral pitch

// graphics tiles
enum game_chars {
    CHAR_SPACE       = ' ',
    // walls and floor of board (must be consecutive)
    CHAR_WALL        = 140,
    CHAR_FLOOR       = 141,
    CHAR_FLOOR_LEFT  = 142,
    CHAR_FLOOR_RIGHT = 143,
    // tetris block types are consecutive from here
    CHAR_BLOCK       = 128,
};

// graphics palettes
enum game_palettes {
    PAL_MAIN    = 0,
    PAL_BLOCK   = 1, // block palettes are consecutive from here
    PAL_BLINK   = 14,
    PAL_ALT     = 15,
};

// high-scores: 1 point per new block, 20 points per completed row
static const uint32_t SCORE_PER_BLOCK = 1;
static const uint32_t SCORE_PER_ROW = 20;


// color per block type, this consists of:
// foreground color, background color, background fade
static const uint16_t BLOCK_COLORS[][3] = {
    {0xf660, 0xfff0, 0x0002}, // yellow box 2x2
    {0xf606, 0xff0f, 0x0020}, // lilac T-shape
    {0xf066, 0xf0ff, 0x0300}, // cyan straight 1x4
    {0xf060, 0xf0f0, 0x0202}, // green S-shape
    {0xf600, 0xff00, 0x0011}, // red Z-shape
    {0xf630, 0xff80, 0x0012}, // orange L-shape
    {0xf006, 0xf00f, 0x0110}, // blue J-shape
};

// 8x8 binary glyphs for block types
static const char BLOCK_GLYPHS[][8] = {
    { 0x1C, 0x36, 0x63, 0x63, 0x63, 0x36, 0x1C, 0x00},   // U+004F (O)
    { 0x3F, 0x2D, 0x0C, 0x0C, 0x0C, 0x0C, 0x1E, 0x00},   // U+0054 (T)
    { 0x1E, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x1E, 0x00},   // U+0049 (I)
    { 0x1E, 0x33, 0x07, 0x0E, 0x38, 0x33, 0x1E, 0x00},   // U+0053 (S)
    { 0x7F, 0x63, 0x31, 0x18, 0x4C, 0x66, 0x7F, 0x00},   // U+005A (Z)
    { 0x0F, 0x06, 0x06, 0x06, 0x46, 0x66, 0x7F, 0x00},   // U+004C (L)
    { 0x78, 0x30, 0x30, 0x30, 0x33, 0x33, 0x1E, 0x00},   // U+004A (J)
};

// 8x8 binary glyphs for walls and floors and decorations
static const char WALL_GLYPHS[][8] = {
    { 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18},   // Wall
    { 0x00, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00},   // Floor
    { 0x30, 0x60, 0xc0, 0x80, 0x00, 0x00, 0x00, 0x00},   // Left corner
    { 0x0c, 0x06, 0x03, 0x01, 0x00, 0x00, 0x00, 0x00},   // Right corner
};

/* Each shape of Tetris block in 4 rotations.
 * There are four pixels per shape, represented as positions, each pixel position is in a (row << 4 | column) format.
*/
static const uint8_t ROTATED_BLOCK_PATTERN[][4] = {
    // O: yellow square 2x2, all rotations the same
    // xx
    // xx
    {0x11, 0x12, 0x21, 0x22},
    {0x11, 0x12, 0x21, 0x22},
    {0x11, 0x12, 0x21, 0x22},
    {0x11, 0x12, 0x21, 0x22},

    // T: lilac T-shape block
    // xxx
    //  x
    {0x11, 0x12, 0x13, 0x22},
    {0x02, 0x12, 0x13, 0x22},
    {0x02, 0x11, 0x12, 0x13},
    {0x02, 0x11, 0x12, 0x22},

    // I: cyan 1x4 block
    // xxxx
    {0x02, 0x12, 0x22, 0x32},
    {0x10, 0x11, 0x12, 0x13},
    {0x02, 0x12, 0x22, 0x32},
    {0x10, 0x11, 0x12, 0x13},

    // S: red 2+2 shifted block
    // xx
    //  xx
    {0x12, 0x13, 0x21, 0x22},
    {0x11, 0x21, 0x22, 0x32},
    {0x12, 0x13, 0x21, 0x22},
    {0x11, 0x21, 0x22, 0x32},

    // Z: green 2+2 shifted block (inverse to red)
    //  xx
    // xx
    {0x11, 0x12, 0x22, 0x23},
    {0x12, 0x21, 0x22, 0x31},
    {0x11, 0x12, 0x22, 0x23},
    {0x12, 0x21, 0x22, 0x31},

    // L: blue 3+1 L-shaped block
    // xxx
    //  .x
    {0x11, 0x12, 0x13, 0x21},
    {0x11, 0x21, 0x31, 0x32},
    {0x23, 0x31, 0x32, 0x33},
    {0x12, 0x13, 0x23, 0x33},

    // J: orange 1+3 L-shaped block
    // xxx
    // x.
    {0x11, 0x12, 0x13, 0x23},
    {0x11, 0x12, 0x21, 0x31},
    {0x21, 0x31, 0x32, 0x33},
    {0x13, 0x23, 0x32, 0x33},
};

// global state
static enum game_state state;
static uint8_t command;

static uint8_t free_rows;
static uint8_t board[ROWS][COLS];     // the main game-board

static bool show_block;
static uint8_t current_index;         // index of the current block (for colorization)
static const uint8_t *current_block;  // bit-pattern of the current block
static uint8_t current_rotation;
static int8_t current_row;            // row of the current block
static int8_t current_col;            // col of the current block

// block animation
static int8_t current_xanim;          // delta of displayed x position to real x position (in screen pixels)
static int8_t current_yanim;          // delta of displayed y position to real y position (in screen pixels)

static uint8_t lines;                 // number of fully removed lines
static uint8_t level;                 // current level
static uint32_t score;                // current game score

static int time_now_ms, time_next_ms;
static int step_ms;                   // time step of the piece to fall one tile

// icestation controller state
static uint16_t p1_current = 0;
static uint16_t p2_current = 0;
static uint16_t p1_edge = 0;
static uint16_t p2_edge = 0;

// 2 fair randomizer pools
static uint8_t shuffled_pool[2][7] = { {0,1,2,3,4,5,6}, {0,1,2,3,4,5,6} };
static uint8_t active_pool = 0; // alternates 0/1
static uint8_t pool_index = 0; // 0-7

// palette fade/blink state
uint8_t fade_intensity = 0;
bool fade_direction = true;

/**
 * Exchange 2 random indices in the pool.
 */
static void shuffle_inactive_pool(void) {
    uint8_t x = 7, y = 7;
    uint8_t i, t;
    while (x == 7)
        x = randbits(3);
    while (y == 7 || y == x)
        y = randbits(3);
    // x=0..6 y=0..6
    i = active_pool ^ 1; // inactive pool
    // exchange using temprary var
    t = shuffled_pool[i][x];
    shuffled_pool[i][x] = shuffled_pool[i][y];
    shuffled_pool[i][y] = t;
}

/**
 * Create fair-random new block
 * from the active shuffled pool
 */
static void create_random_block(void) {
    uint8_t x;
    shuffle_inactive_pool();
    x = shuffled_pool[active_pool][pool_index];
    if (++pool_index == 7) {
        pool_index = 0;
        active_pool ^= 1;
    }
    current_index = x;
    current_rotation = 0;
    current_block = ROTATED_BLOCK_PATTERN[current_index * 4 + (current_rotation & 3)];
}

/**
 * Rotate current block by a multiple of 90 degrees.
 */
static void rotate_block(char r) {
    current_rotation = (current_rotation + r) & 3;
    current_block = ROTATED_BLOCK_PATTERN[current_index * 4 + (current_rotation & 3)];
}

/**
 * Accessor function for the gaming board position at (row,col).
 * Use val=1 for occupied and val=0 for empty places.
 */
static void set_pixel(uint8_t row, uint8_t col, uint8_t val) {
    board[row][col] = val;
}

/**
 * Get raw pixel value at a position on the board.
 */
static uint8_t get_pixel(uint8_t row, uint8_t col) {
    return board[row][col];
}

/**
 * Check whether the gaming board position at (row,col) is occupied.
 */
static bool occupied(uint8_t row, uint8_t col) {
    return board[row][col] != 0;
}

/**
 * Clear the whole gaming board.
 */
static void clear_board(void) {
    for (uint8_t r = 0; r < ROWS; r++) {
        for (uint8_t c = 0; c < COLS; c++) {
            set_pixel(r, c, 0);
        }
    }
}

/**
 * Check whether the current block fits at the position given by
 * (current_row, current_col).
 * Returns 1 if the block fits, and 0 if not.
 */
static bool test_if_block_fits(void) {
    for (uint8_t idx = 0; idx < 4; ++idx) {
        int cri = current_row + (current_block[idx] >> 4);
        int ccj = current_col + (current_block[idx] & 0xf);

        if (ccj < 0) return 0; // too far left
        if (ccj >= COLS)  return 0; // too far right
        if (cri >= ROWS) return 0; // too low

        if (occupied(cri, ccj)) return 0;
    }

    return 1; // block fits
}

/**
 * Copy the bits from the current block at its current position
 * to the gaming board. This means to fix the current 'foreground'
 * block into the static 'background' gaming-board pattern.
 */
static void copy_block_to_gameboard(void) {
    for (uint8_t idx = 0; idx < 4; ++idx) {
        uint8_t cri = current_row + (current_block[idx] >> 4);
        uint8_t ccj = current_col + (current_block[idx] & 0xf);

        set_pixel(cri, ccj, current_index + 1);
    }
}

/**
 * Check whether the specified game-board row (0=top,23=bottom)
 * is complete (all bits set) or not.
 */
static bool is_complete_row(uint8_t r) {
    for (uint8_t c = 0; c < COLS; c++) {
        if (!occupied(r, c))
            return 0;
    }

    return 1;
}

/**
 * Remove one (presumed complete) row from the game-board,
 * so that all rows above the specified row drop one level.
 */
static void remove_row(uint8_t row) {
    for (uint8_t c = 0; c < COLS; c++) {
        for (uint8_t r = row; r > 0; r--) {
            set_pixel(r, c, get_pixel(r-1, c));
        }

        // finally, clear topmost pixel
        set_pixel(0, c, 0);
    }
}

/**
 * Put a single character or other tile on the screen.
 */
static void scr_putc(uint8_t y, uint8_t x, uint16_t palette_mask, char c) {
    uint16_t map = c & 0xff;
    map |= palette_mask;

    uint16_t address = y * 64 + x % 64 + ((x % 128) >= 64 ? 0x1000 : 0);
    vdp_seek_vram(MAP_VRAM_BASE + address);
    vdp_write_vram(map);
}

/** Clear screen.
 */
static void scr_clear(void) {
    vdp_seek_vram(MAP_VRAM_BASE);
    vdp_fill_vram(0x2000, ' ');
}

/**
 * Make a sound.
 */
static void sound_play(enum game_sound ch) {
    AUDIO_GB_PLAY = 1 << ch;
}

/**
 * Print the given integer value, zero-padded to provided width.
 * values that don't fit will be truncated.
 */
static void scr_zpadnum(uint8_t y, uint8_t x, uint16_t palette_mask, uint32_t val, uint8_t width) {
    x += width - 1;
    for (uint8_t i = 0; i < width; ++i) {
        scr_putc(y, x, palette_mask, '0' + (val % 10));
        val /= 10;
        --x;
    }
}

/**
 * Print a string.
 */
static void scr_puts(uint8_t y, uint8_t x, uint16_t palette_mask, char *s) {
    while (*s) {
        scr_putc(y, x, palette_mask, *s);
        ++x;
        ++s;
    }
}

/**
 * Display (or erase) the current block at its current position,
 * depending on the show_block global.
 */
static void update_block_sprites(void) {
    vdp_seek_sprite(0);
    if (!show_block) {
        // tetris pieces have four blocks, so only four sprites will be in use
        for (uint8_t idx = 0; idx < 4; ++idx) {
            vdp_write_sprite_meta(0, SCREEN_ACTIVE_HEIGHT, 0);
        }
    } else {
        uint16_t sprite_g = (CHAR_BLOCK + current_index) | ((PAL_BLOCK + current_index) << SPRITE_PAL_SHIFT) | (3 << SPRITE_PRIORITY_SHIFT);
        for (uint8_t idx = 0; idx < 4; ++idx) {
            uint8_t cri = current_row + (current_block[idx] >> 4);
            uint8_t crj = current_col + (current_block[idx] & 0xf);
            vdp_write_sprite_meta(((BOARD_X + crj) * 8 + current_xanim) & 0x3ff,
                    ((BOARD_Y + cri - ROW0) * 8 + current_yanim) & 0x1ff,
                    sprite_g);
        }
    }
}

/**
 * Display the current game board.
 * This method redraws the whole gaming board including borders.
 */
static void display_board(void) {
    uint8_t r, c;

    for (r = 0; r < ROWSD; r++) {
        scr_putc(BOARD_Y + r, BOARD_X - 1, 0, CHAR_WALL);            // one row of the board: border, data, border

        for (c = 0; c < COLS; c++) {
            uint8_t val = get_pixel(r + ROW0, c);
            uint16_t tile;
            if (val != 0) { // Part of block
                tile =  ((PAL_BLOCK + val - 1) << SCROLL_MAP_PAL_SHIFT);
                tile |= CHAR_BLOCK + val - 1;
            } else { // Background
                tile = (c & 1) ? (PAL_ALT << SCROLL_MAP_PAL_SHIFT) : (PAL_MAIN << SCROLL_MAP_PAL_SHIFT);
                tile |= CHAR_SPACE;
            }
            scr_putc(BOARD_Y + r, BOARD_X + c, tile, 0);
        }

        scr_putc(BOARD_Y + r, BOARD_X + COLS, 0, CHAR_WALL);
    }

    // print floor
    scr_putc(BOARD_Y + r, BOARD_X - 1, 0, CHAR_FLOOR_LEFT);
    for(c = 0; c < COLS; c++)
        scr_putc(BOARD_Y + r, BOARD_X + c, 0, CHAR_FLOOR);
    scr_putc(BOARD_Y + r, BOARD_X + COLS, 0, CHAR_FLOOR_RIGHT);
}

/**
 * Display the current level and score values, and paused state.
 */
static void display_score(void) {
    const uint16_t blink = PAL_BLINK << SCROLL_MAP_PAL_SHIFT;

    scr_puts(INFO_Y, INFO_X + 0, 0, "Level: ");
    scr_zpadnum(INFO_Y, INFO_X + 7, 0, level, 2);

    scr_puts(INFO_Y + 1, INFO_X + 0, 0, "Score: ");
    scr_zpadnum(INFO_Y + 1, INFO_X + 7, 0, score, 4);

    if (state == PAUSED) {
        scr_puts(INFO_Y + 3, INFO_X + 0, blink, "[Paused]");
    } else {
        scr_puts(INFO_Y + 3, INFO_X + 0, blink, "        ");
    }
}

// Efficiently center fixed-length message.
#define CENTER(y, color, message) scr_puts(y, TILES_W / 2 - (sizeof(message) - 1) / 2, color, message)

/**
 * Called when the game starts initially.
 */
static void do_beginning(void) {
    const uint16_t blink = PAL_BLINK << SCROLL_MAP_PAL_SHIFT;
    scr_clear();
    show_block = false;

    CENTER(TILES_H / 2 - 2, 0, "Welcome to IceTetris!");
    CENTER(TILES_H / 2 + 2, blink, "Press [Start] to start.");
}

/**
 * Called when the game is over.
 */
static void do_gameover(void) {
    const uint16_t blink = PAL_BLINK << SCROLL_MAP_PAL_SHIFT;
    scr_clear();
    show_block = false;

    CENTER(TILES_H / 2 - 1, 0, "Game over!");

    scr_puts(TILES_H / 2 + 1, 40, 0, "Level: ");
    scr_zpadnum(TILES_H / 2 + 1, 47, 0, level, 2);

    scr_puts(TILES_H / 2 + 1, 50, 0, "Score: ");
    scr_zpadnum(TILES_H / 2 + 1, 57, 0, score, 4);

    CENTER(TILES_H / 2 + 3, blink, "Press [Start] to start a new game.");
}

/**
 * Enter the specified game state.
 */
static void set_state(enum game_state s) {
    enum game_state oldstate = state;
    state = s;

    /* Leaving state. */
    switch (oldstate) {
        case PAUSED:
            display_score();
            break;
        default:
            break;
    }

    /* Entering state. */
    switch (state) {
        case GAME_OVER:
            do_gameover();
            break;
        case BEGINNING:
            do_beginning();
            break;
        case PAUSED:
            display_score();
            break;
        default:
            break;
    }
}

/**
 * Check for completed rows and remove them from the gaming board.
 */
static void check_remove_completed_rows(void) {
    uint8_t r, removed;

    removed = 0;
    for (r = 0; r < ROWS; r++) {
        if (is_complete_row(r)) {
            removed++;
            break;
        }
    }

    removed = 0;
    for (r = 0; r < ROWS; r++) {
        if (is_complete_row(r)) {
            removed++;
            remove_row(r);
            score += SCORE_PER_ROW;
            if (++lines == 4) {
                lines = 0;
                if (level < MAX_level) {
                    level++;
                    step_ms = STEP_FASTER(step_ms); // 3/4 times game speedup
                }
            }
        }
    }

    if (current_row < free_rows)
        free_rows = current_row;
    free_rows += removed;

    if (removed) {
        sound_play(SND_LONGBEEP);
    }
    display_board();
    display_score();
}

/**
 * Try to move the current block left.
 * This function updates the current_col variable.
 */
static void cmd_move_left(void) {
  current_col--;
  if (test_if_block_fits()) {
      current_xanim = 8;
      return;
  }

  // If we arrive here, the block doesn't fit,
  // and we simply undo the column change.
  current_col++;
}

/**
 * Try to move the current block right.
 * This function updates the current_col variable.
 */
static void cmd_move_right(void) {
    current_col++;
    if (test_if_block_fits()) {
        current_xanim = -8;
        return;
    }

    // If we arrive here, the block doesn't fit,
    // and we simply undo the column change.
    current_col--;
}

/**
 * Try to rotate the current block.
 * This function updates the current_block variable.
 */
static void cmd_rotate(char r) {
    rotate_block(r);
    if (test_if_block_fits()) return;

    // If we arrive here, the block doesn't fit,
    // and we undo the rotation by three more rotations...
    rotate_block(-r);
}

/**
 * Attempt to move the current block one position down.
 * If it doesn't fit, copy the current block to the gaming board
 * and check for completed rows. If any completed rows are found,
 * check_remove_completed_rows() also automatically repaints the
 * whole gaming board.
 * Finally, we create a new random block.
 */
static void cmd_move_down(void) {
    current_row++;
    if (test_if_block_fits()) {
        current_yanim = -8;
        return; // fits
    }

    if (current_row <= ROWNEW + 2) { // already stuck right on top
        set_state(GAME_OVER);
        return;
    }

    // If we arrive here, the block doesn't fit,
    // and we have to copy it to the game board.
    // we also need a new random block...
    current_row--;

    sound_play(SND_SHORTBEEP);
    copy_block_to_gameboard();
    check_remove_completed_rows(); // repaints all when necessary

    current_row = ROWNEW;
    current_col = COLNEW;
    current_yanim = -8;

    create_random_block();
    score += SCORE_PER_BLOCK;
}

/**
 * Set the time target value for the next automatic downward move.
 */
static void set_next_step_timeout(void) {
    time_next_ms = time_next_ms + step_ms;
}

/**
 * Check for timed downward movement.
 */
static void check_for_timeout(void) {
    if (time_now_ms >= time_next_ms) {
        set_next_step_timeout();
        // Don't time out while paused, but keep bumping the next step timeout nevertheless,
        // to avoid a sudden avalanche of blocks after unpausing.
        if (state == PLAYING) {
            set_state(TIMEOUT);
        }
    }
}

/**
 * Initialize game state for a new game.
 */
static void init_game(void) {
    scr_clear();
    clear_board();
    display_board();

    srand(time_now_ms); // seed RNG with current time
    free_rows = ROWS;
    for(uint8_t i = 0; i < 7; i++) {
      active_pool = 1;
      shuffle_inactive_pool();
      active_pool = 0;
      shuffle_inactive_pool();
    }
    current_row = ROWNEW;
    current_col = COLNEW;
    create_random_block();

    score = SCORE_PER_BLOCK;  // one block created right now
    lines = 0;
    level = 1;
    time_next_ms = time_now_ms;
    step_ms = MS_STEP_START; // level 1 step 1 s -> level 9 step 0.1 s
    set_next_step_timeout();

    state = PLAYING;
    command = CMD_NONE;
    show_block = true;
}

static void check_handle_command(void) {
    uint8_t tmp;
    int8_t previous_row;

    switch (state) {
        case BEGINNING: // if in begin screen, only CMD_START will start the game
            if (command == CMD_START) {
                init_game();
            }
            return;
        case GAME_OVER: // if the game is over, we only react to the restart command.
            if (command == CMD_START) {
                init_game();
            }
            return;
        case PAUSED: // if paused, don't respond to any commands except to unpause
            if (command == CMD_START) {
                set_state(PLAYING);
            }
            command = CMD_NONE;
            return;
        case TIMEOUT: // check for possible timeout.
            cmd_move_down();
            if (state == TIMEOUT) { // not gameover by now?
                set_state(PLAYING);
            }
            return;
        case PLAYING: // check whether we have a command. If so, handle it.
            tmp = command;
            command = CMD_NONE;

            switch (tmp) {
                case CMD_LEFT: // try to move the current block left
                    cmd_move_left();
                    break;

                case CMD_ROTATE_CCW: // try to rotate the current block
                    cmd_rotate(1);
                    break;

                case CMD_ROTATE_CW: // try to rotate the current block
                    cmd_rotate(-1);
                    break;

                case CMD_RIGHT: // try to move the current block right
                    cmd_move_right();
                    break;

                case CMD_DROP: // drop the current block
                    previous_row = current_row;
                    for( ; test_if_block_fits(); ) current_row++;

                    // now one step back, then paint the block in its
                    // final position and allow to move left-right
                    // before sticking it finally
                    current_row--;

                    if (previous_row != current_row) {
                        // after drop, reset step time to proprely delay final "stick"
                        current_yanim = -8; // soft landing
                        time_next_ms = time_now_ms;
                        set_next_step_timeout();
                    }
                    break;

                case CMD_START: // quit and (re-) start the game
                    set_state(PAUSED);
                    break;

                default:
                    // do nothing
                    break;
            }
            return;
    }
}

/**
 * Blink a palette color.
 */
static void animate_palette(void) {
    if (fade_direction) {
        fade_intensity += 1;
        if (fade_intensity == 63) {
            fade_direction = false;
        }
    } else {
        fade_intensity -= 1;
        if (fade_intensity == 0) {
            fade_direction = true;
        }
    }
    vdp_set_single_palette_color(PAL_BLINK * 16 + 0x2,
        0xf000 | // Fading Alpha as well would create a kind of quadratic effect.
        (fade_intensity >> 2) << 8 |
        (fade_intensity >> 2) << 4 |
        (fade_intensity >> 2) << 0);

}

/**
 * Animate block sprite movement. This movement is purely visual and does not
 * affect the game logic.
 */
static void animate_movement(void) {
    if (state == PAUSED)
        return;

    // This is a really simple animation. It moves the block into place,
    // linearly correcting the current delta towards zero.
    if (current_xanim < 0)
        current_xanim += 1;
    if (current_xanim > 0)
        current_xanim -= 1;
    if (current_yanim < 0)
        current_yanim += 1;
    if (current_yanim > 0)
        current_yanim -= 1;
}

/**
 * Input processing.
 */
static void process_gamepad_input(void) {
    pad_read(&p1_current, &p2_current, &p1_edge, &p2_edge);

    if (p1_edge & GP_DOWN) {
        command = CMD_DROP;
    }
    if (p1_edge & GP_LEFT) {
        command = CMD_LEFT;
    }
    if (p1_edge & GP_RIGHT) {
        command = CMD_RIGHT;
    }
    // Allow using either the shoulder buttons or B/Y to rotate blocks,
    // depending on the gamepad either can be more convenient.
    if (p1_edge & (GP_L | GP_B)) {
        command = CMD_ROTATE_CCW;
    }
    if (p1_edge & (GP_R | GP_Y)) {
        command = CMD_ROTATE_CW;
    }
    // Both START and SELECT trigger the START command because the ULX3S board doesn't have a
    // START button.
    if (p1_edge & (GP_START | GP_SELECT)) {
        command = CMD_START;
    }
}

/**
 * Font upload with a background image instead of a single transparent color.
 */
static void upload_font_with_background(uint16_t vram_base, uint8_t bg[8][8], uint8_t opaque, const char font[][8], uint16_t char_total) {
    vdp_seek_vram(vram_base);
    vdp_set_vram_increment(1);

    for (uint32_t char_id = 0; char_id < char_total; char_id++) {
        for(uint32_t line = 0; line < 8; line++) {
            uint32_t monochrome_line = font[char_id][line];
            uint32_t rendered_line = 0;

            for (uint32_t pixel = 0; pixel < 8; pixel++) {
                rendered_line <<= 4;
                rendered_line |= (monochrome_line & 0x01) ? opaque : bg[line][pixel];

                monochrome_line >>= 1;
            }

            vdp_write_vram(rendered_line & 0xffff);
            vdp_write_vram(rendered_line >> 16);
        }
    }
}

int main(void) {
    vdp_enable_layers(SCROLL0 | SPRITES);
    vdp_set_wide_map_layers(SCROLL0);
    vdp_set_alpha_over_layers(0);

    vdp_set_vram_increment(1);

    vdp_set_layer_scroll(0, 0, 0);
    vdp_clear_all_sprites();

    vdp_seek_vram(0x0000);
    vdp_fill_vram(0x8000, ' ');

    vdp_set_layer_tile_base(0, TILE_VRAM_BASE);
    vdp_set_layer_map_base(0, MAP_VRAM_BASE);
    vdp_set_sprite_tile_base(TILE_VRAM_BASE);
    upload_font_remapped(TILE_VRAM_BASE, 1, 2);
    upload_font_remapped_main(TILE_VRAM_BASE + 16 * CHAR_WALL, 1, 2, WALL_GLYPHS, sizeof(WALL_GLYPHS) / 8);

    // Set up block glyph tiles
    //   Make "frosted look" for block tile background.
    uint8_t background[8][8];
    for(uint32_t line = 0; line < 4; line++) {
        for (uint32_t pixel = 0; pixel < 4; pixel++) {
            uint8_t v = 5 - (line < pixel ? line : pixel);
            background[line][pixel] = v;
            background[line][7 - pixel] = v;
            background[7 - line][pixel] = v;
            background[7 - line][7 - pixel] = v;
        }
    }

    //   Upload the tiles with glyphs on top.
    upload_font_with_background(TILE_VRAM_BASE + 16 * CHAR_BLOCK, background, 1, BLOCK_GLYPHS, sizeof(BLOCK_GLYPHS) / 8);

    // Set up palette
    const uint16_t screen_bg = 0x0000;
    const uint16_t font_fg = 0xfccc;

    //   Text colors
    vdp_set_single_palette_color(PAL_MAIN * 16 + 0x0, screen_bg);
    vdp_set_single_palette_color(PAL_MAIN * 16 + 0x1, screen_bg);
    vdp_set_single_palette_color(PAL_MAIN * 16 + 0x2, font_fg);

    vdp_set_single_palette_color(PAL_BLINK * 16 + 0x1, screen_bg); // blinking text
    vdp_set_single_palette_color(PAL_BLINK * 16 + 0x2, 0xffff);

    vdp_set_single_palette_color(PAL_ALT * 16 + 0x1, 0x4444); // background striping
    vdp_set_single_palette_color(PAL_ALT * 16 + 0x2, font_fg);

    //   Block colors
    for (uint8_t idx = 0; idx < NUM_SHAPES; ++idx) {
        vdp_seek_palette((PAL_BLOCK + idx) * 16 + 0x1);
        vdp_write_palette_color(BLOCK_COLORS[idx][0]);

        uint16_t color = BLOCK_COLORS[idx][1];
        for (uint8_t f = 0; f < 4; ++f) {
            vdp_write_palette_color(color);
            color += BLOCK_COLORS[idx][2];
        }
    }

    // Audio setup
    for (uint32_t i = 0; i < sizeof(SAMPLE_POINTERS) / sizeof(int16_t*); i++) {
        volatile AudioChannel *ch = &AUDIO->channels[i];
        audio_set_aligned_addresses(ch, SAMPLE_POINTERS[i], *SAMPLE_LENGTHS[i]);
        ch->pitch = PITCH;
        ch->flags = 0;
        ch->volumes.left = VOLUME;
        ch->volumes.right = VOLUME;
    }

    // Start frame loop
    set_state(BEGINNING);

    fade_intensity = 0;
    fade_direction = true;

    while (true) {
        process_gamepad_input();

        check_for_timeout();

        check_handle_command();

        update_block_sprites();

        animate_movement();
        animate_palette();

        vdp_wait_frame_ended();
        time_now_ms += FRAME_MS;
    }
}
