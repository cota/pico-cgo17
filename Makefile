SHELL = /bin/bash
QEMU := qemu
CK := ck

CONFIG_X86 := ./configure --target-list=x86_64-softmmu,x86_64-linux-user --disable-werror
CONFIG_A64 := ./configure --target-list=aarch64-linux-user --disable-werror
CONFIG_A64_TSX := ./configure --target-list=aarch64-linux-user --disable-werror --extra-cflags="-mrtm"

test: deps
	$(MAKE) -C $(QEMU)
	@echo "pico-cgo17: test OK"

deps: $(CK)/src/libck.a $(QEMU)/config.status

$(QEMU)/config.status:
	cd $(QEMU) && $(CONFIG_X86)

.PHONY: deps

$(CK)/src/libck.a: $(CK)/Makefile
	$(MAKE) -C $(CK)

$(CK)/Makefile:
	cd $(CK) && ./configure

rep6: deps
	cd $(QEMU) && git checkout fig6 && $(CONFIG_X86) && $(MAKE) tests/test-qht-par && cp tests/test-qht-par ../bin/x86_64-test-qht-par && $(MAKE) distclean
.PHONY: rep6

# Note: cannot have several builds in parallel
x86_64: deps
	cd $(QEMU) && git checkout x86_64-baseline  && $(CONFIG_X86) && $(MAKE) && cp x86_64-linux-user/qemu-x86_64 ../bin/x86_64-baseline-user && $(MAKE) distclean
	cd $(QEMU) && git checkout x86_64-pico      && $(CONFIG_X86) && $(MAKE) && cp x86_64-linux-user/qemu-x86_64 ../bin/x86_64-pico-user && $(MAKE) distclean
.PHONY: x86_64

power: deps
	cd $(QEMU) && for var in nobarr powera sao sync; do \
		git checkout pico-power-$$var && $(CONFIG_X86) && $(MAKE) && \
		cp x86_64-linux-user/qemu-x86_64 ../bin/power-pico-$$var; \
	done && $(MAKE) distclean
.PHONY: power

bin/x86_64-atomic_add: deps
	cd $(QEMU) && git checkout master && $(CONFIG_X86) && $(MAKE) tests/atomic_add-bench && cp tests/atomic_add-bench ../$@ && $(MAKE) distclean

atomic_add: bin/x86_64-atomic_add
.PHONY: atomic_add

cas: atomic_add
	$(MAKE) x86_64
	cd $(QEMU) && git checkout pico-slow-cmpxchg && $(CONFIG_X86) && $(MAKE) && cp x86_64-linux-user/qemu-x86_64 ../bin/x86_64-pico-cas && $(MAKE) distclean

st: deps
	cd $(QEMU) && for var in baseline pico-cas pico-st; do \
		git checkout aarch64-$$var && $(CONFIG_A64) && $(MAKE) && \
		cp aarch64-linux-user/qemu-aarch64 ../bin/aarch64-$$var; \
	done && $(MAKE) distclean
.PHONY: deps

tsx: st
	cd $(QEMU) && git checkout aarch64-pico-htm && $(CONFIG_A64_TSX) && \
	$(MAKE) && \
	cp aarch64-linux-user/qemu-aarch64 ../bin/aarch64-pico-htm && \
	$(MAKE) distclean
.PHONY: tsx

test_all:
	$(MAKE) rep6
	$(MAKE) x86_64
	$(MAKE) atomic_add
	$(MAKE) cas
	$(MAKE) st
.PHONY: test_all

clean:
	$(RM) bin/x86_64-* power-*
.PHONY: clean

distclean: clean
	$(MAKE) -C qemu distclean
	$(MAKE) -C ck distclean
	$(RM) -r spec06/benchspec/CPU2006/*/run/*
	$(RM) -r spec06-aarch64/benchspec/CPU2006/*/run/*
.PHONY: distclean
