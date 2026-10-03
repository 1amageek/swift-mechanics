#ifndef C_MECHANICS_MATH_H
#define C_MECHANICS_MATH_H
#include <math.h>

// System libm provides the same mathematical boundary on Darwin, Linux and WASI.
static inline double sm_sin(double value) { return sin(value); }
static inline double sm_cos(double value) { return cos(value); }
static inline double sm_atan2(double y, double x) { return atan2(y, x); }
static inline double sm_hypot(double x, double y) { return hypot(x, y); }
#endif
