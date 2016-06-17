import sys
from scipy.ndimage.filters import gaussian_filter, sobel
import numpy as np
cimport numpy as np

from numpy.math cimport INFINITY

cdef int height, width, disp_max

cdef int L1 = 34
cdef int L2 = 17
cdef int tau1 = 20
cdef int tau2 = 6

cdef double pi1 = 1.
cdef double pi2 = 3.
cdef int tau_so = 15

cdef int tau_s = 20
cdef int tau_h = 0.4

cdef int tau_E = 10

def int(int h, int w, int d):
    global height, width, disp_max

    height = h
    width = w
    disp_max = d
