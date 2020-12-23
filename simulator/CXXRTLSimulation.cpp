#include "CXXRTLSimulation.hpp"

// Flash blackbox:

class SPIFlashBlackBox : public cxxrtl_design::bb_p_flash__bb {

public:
    SPIFlashBlackBox(QSPIFlashSim flash) : flash(flash) {};

    bool eval() override {
        uint8_t io = flash.update(p_csn.get<bool>(), p_clk.get<bool>(), p_in.get<uint8_t>());
        flash.check_conflicts(p_in__en.get<uint8_t>());
        p_out.set(io);
        
        return bb_p_flash__bb::eval();
    }

private:
    QSPIFlashSim flash;
};

// Audio blackbox:

class AudioDACSampleSink {

public:
    static AudioDACSampleSink default_sink;

    void set_samples(int16_t left, int16_t right) {
        samples_pending_fetch = true;
        this->left = left;
        this->right = right;
    }

    bool get_samples(int16_t *left, int16_t *right) {
        if (!samples_pending_fetch) {
            return false;
        }

        assert(left);
        assert(right);

        *left = this->left;
        *right = this->right;
        samples_pending_fetch = false;

        return true;
    }

private:
    bool samples_pending_fetch = false;
    int16_t left = 0, right = 0;
};

AudioDACSampleSink AudioDACSampleSink::default_sink = AudioDACSampleSink();

class AudioDACBlackBox : public cxxrtl_design::bb_p_audio__dac__bb {

public:
    AudioDACBlackBox(AudioDACSampleSink sample_sink) : sample_sink(sample_sink) {};

    bool eval() override {
        if (posedge_p_clk()) {
            sample_sink.set_samples(static_cast<int16_t>(p_in__l.get<uint16_t>()), static_cast<int16_t>(p_in__r.get<uint16_t>()));
        }

        return bb_p_audio__dac__bb::eval();
    }

private:
    AudioDACSampleSink sample_sink;
};

namespace cxxrtl_design {

std::unique_ptr<bb_p_flash__bb> bb_p_flash__bb::create(std::string name, metadata_map parameters, metadata_map attributes) {
    return std::make_unique<SPIFlashBlackBox>(Simulation::default_flash);
}

std::unique_ptr<bb_p_audio__dac__bb> bb_p_audio__dac__bb::create(std::string name, metadata_map parameters, metadata_map attributes) {
    return std::make_unique<AudioDACBlackBox>(AudioDACSampleSink::default_sink);
}

}

void CXXRTLSimulation::preload_cpu_program(const std::vector<uint8_t> &program) {
    auto & cpu_ram_0 = top.memory_p_ics32_2e_cpu__ram_2e_cpu__ram__0_2e_mem;
    auto & cpu_ram_1 = top.memory_p_ics32_2e_cpu__ram_2e_cpu__ram__1_2e_mem;

    size_t ipl_load_length = std::min((size_t)0x10000, program.size());

    for (size_t i = 0; i < ipl_load_length / 4; i++) {
        uint16_t low_word = program[i * 4] | program[i * 4 + 1] << 8;
        uint16_t high_word = program[i * 4 + 2] | program[i * 4 + 3] << 8;

        cpu_ram_0[i] = value<16>{low_word};
        cpu_ram_1[i] = value<16>{high_word};
    }
}

uint8_t CXXRTLSimulation::r() const {
    return top.p_vga__r.get<uint8_t>();
}

uint8_t CXXRTLSimulation::g() const { 
    return top.p_vga__g.get<uint8_t>();
}

uint8_t CXXRTLSimulation::b() const { 
    return top.p_vga__b.get<uint8_t>();
}

bool CXXRTLSimulation::hsync() const { 
    return top.p_vga__hsync.get<bool>();
}

bool CXXRTLSimulation::vsync() const { 
    return top.p_vga__vsync.get<bool>();
}

void CXXRTLSimulation::final() {
#if VCD_WRITE
    vcd_stream.close();
#endif
}

bool CXXRTLSimulation::finished() const { 
    return false;
}

void CXXRTLSimulation::step(uint64_t time) {
    // using .set() has a severe performance impact (to profile and confirm)
    top.p_clk__1x = value<1>{clk_1x};
    top.p_clk__2x = value<1>{clk_2x};

    top.p_btn__u.set(button_user);
    top.p_btn__1.set(button_1);
    top.p_btn__2.set(button_2);
    top.p_btn__3.set(button_3);
    
    top.step();

#if VCD_WRITE
    update_trace(time);
#endif
}

bool CXXRTLSimulation::get_samples(int16_t *left, int16_t *right) {
    return AudioDACSampleSink::default_sink.get_samples(left, right);
}

#if VCD_WRITE

void CXXRTLSimulation::trace(const std::string &filename) {
    vcd_stream.exceptions(std::ofstream::failbit | std::ofstream::badbit);
    vcd_stream.open(filename, std::ios::out);

    cxxrtl::debug_items debug;
    top.debug_info(debug);

    vcd.timescale(1, "ns");

    // for now, just filter to a few signals of interest
    const std::vector<std::string> filter_names = {"pico", "clk", "reset", "valid", "ready"};

    vcd.add(debug, [&](const std::string &name, const debug_item &item) {
        for (auto filter_name : filter_names) {
            if (name.find(filter_name) != std::string::npos) {
                return true;
            }
        }

        return false;
    });
}

void CXXRTLSimulation::update_trace(uint64_t time) {
    vcd.sample(time);

    vcd_stream << vcd.buffer;
    vcd.buffer.clear();
}

#endif
