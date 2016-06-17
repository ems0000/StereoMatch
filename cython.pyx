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

def ad_vol(np.ndarray[np.float64_t, ndim=3] x0, np.ndarray[np.float64_t, ndim=3] x1):
    cdef np.ndarray[np.float64_t, ndim=3] res
    cdef int d, i, j, c

    res = np.zeros((disp_max, height, width))
    for d in range(disp_max):
        for i in range(height):
            for j in range(width):
                if j - d < 0:
                    res[d,i,j] = INFINITY
                else:
                    for c in range(3):
                        res[d,i,j] += abs(x0[i,j,c] - x1[i,j-d,c])
                    res[d,i,j] /= 3
    return res
    
def census_transform(np.ndarray[np.float64_t, ndim=3] x):
    cdef np.ndarray[np.int_t, ndim=3] cen
    cdef int i, j, ii, jj, k, ind, ne

    ne = np.random.randint(2**31-1)
    cen = np.zeros((height, width, 63 * 3), dtype=np.int)
    for i in range(height):
        for j in range(width):
            ind = 0
            for ii in range(i - 3, i + 4):
                for jj in range(j - 4, j + 5):
                    for k in range(3):
                        if 0 <= ii < height and 0 <= jj < width:
                            cen[i, j, ind] = x[ii, jj, k] < x[i, j, k]
                        else:
                            cen[i, j, ind] = ne
                        ind += 1
    return cen
