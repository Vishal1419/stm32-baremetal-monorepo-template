###############################################################################
# libs.mk - library registrations for this sub-project
#
# Format (Make 3.81 compatible - plain variable assignments only):
#
#   LIBS   += <dir>:<libname>:<build-target>
#   SHARED += <dir>
#
# libname must match what the library's own Makefile produces (without lib prefix and .a).
# libopencm3 produces: libopencm3_stm32f7.a -> libname = opencm3_stm32f7
#
# DO NOT use $(call) or $(eval) here - not compatible with Make 3.81.
# DO NOT edit the libopencm3 line manually.
###############################################################################

# libopencm3
# MCU_FAMILY e.g. stm32/f7 -> libname opencm3_stm32f7 -> libopencm3_stm32f7.a
LIBS += submodules/libopencm3:opencm3_$(subst /,,$(MCU_FAMILY)):$(MCU_FAMILY)

# Shared libraries - managed by: make add-shared APP=<app> SHARED=<n>
# Do not edit manually.
