ifneq ($(UTILITY_MK), 1)

UTILITY_MK := 1

define persisted_var
$(call persisted_var_path,$1,$1)
endef

define persisted_var_path
.PHONY: dummy_$($1)
$2: dummy_$($1)
	@if [[ `cat $2 2>&1` != '$($1)' ]]; then \
		echo $($1) > $2 ; \
		echo '$1 has changed to $($1). Will rebuild its dependencies..' ; \
	fi
endef

endif

