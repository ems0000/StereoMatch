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

cdef int cross_coditions(int i, int j, int ii, int jj, int iii, int jjj,
                         np.ndarray[np.float64_t, ndim=3] x):
    cdef double v0, v1, v2

    if not (0 <= ii < height and 0 <= jj < width): return 0

    if abs(i - ii) == 1 or abs(j - jj) == 1: return 1

    # rule 1
    if abs(x[i,j,0] - x[ii,jj,0]) >= tau1: return 0
    if abs(x[i,j,1] - x[ii,jj,1]) >= tau1: return 0
    if abs(x[i,j,2] - x[ii,jj,2]) >= tau1: return 0

    if abs(x[ii,jj,0] - x[iii,jjj,0]) >= tau1: return 0
    if abs(x[ii,jj,1] - x[iii,jjj,1]) >= tau1: return 0
    if abs(x[ii,jj,2] - x[iii,jjj,2]) >= tau1: return 0

    # rule 2
    if abs(i - ii) >= L1 or abs(j - jj) >= L1: return 0

    # rule 3
    if abs(i - ii) >= L2 or abs(j - jj) >= L2:
        if abs(x[i,j,0] - x[ii,jj,0]) >= tau2: return 0
        if abs(x[i,j,1] - x[ii,jj,1]) >= tau2: return 0
        if abs(x[i,j,2] - x[ii,jj,2]) >= tau2: return 0
        
    return 1
    

def cross(np.ndarray[np.float64_t, ndim=3] x):
    cdef np.ndarray[np.int_t, ndim=3] res
    cdef int i, j, yn, ys, xe, xw
    
    res = np.empty((height, width, 4), dtype=np.int)
    for i in range(height):
        for j in range(width):
            res[i,j,0] = i - 1
            res[i,j,1] = i + 1
            res[i,j,2] = j - 1
            res[i,j,3] = j + 1
            while cross_coditions(i,j,res[i,j,0],j,res[i,j,0]+1,j,x): res[i,j,0] -= 1
            while cross_coditions(i,j,res[i,j,1],j,res[i,j,1]-1,j,x): res[i,j,1] += 1
            while cross_coditions(i,j,i,res[i,j,2],i,res[i,j,2]+1,x): res[i,j,2] -= 1
            while cross_coditions(i,j,i,res[i,j,3],i,res[i,j,3]-1,x): res[i,j,3] += 1
    return res

def cbca(np.ndarray[np.int_t, ndim=3] x0c,
         np.ndarray[np.int_t, ndim=3] x1c,
         np.ndarray[np.float64_t, ndim=3] vol,
         int t):
    cdef np.ndarray[np.float64_t, ndim=3] res
    cdef int i, j, ii, jj, ii_s, ii_t, jj_s, jj_t, d, cnt
    cdef double sum

    res = np.empty_like(vol)
    for d in range(disp_max):
        for i in range(height):
            for j in range(width):
                if j - d < 0:
                    res[d,i,j] = vol[d,i,j]
                    continue
                sum = 0
                cnt = 0
                if t:
                    # horizontal then vertical
                    jj_s = max(x0c[i,j,2], x1c[i,j-d,2] + d) + 1
                    jj_t = min(x0c[i,j,3], x1c[i,j-d,3] + d)
                    for jj in range(jj_s, jj_t):
                        ii_s = max(x0c[i,jj,0], x1c[i,jj-d,0]) + 1
                        ii_t = min(x0c[i,jj,1], x1c[i,jj-d,1])
                        for ii in range(ii_s, ii_t):
                            sum += vol[d, ii, jj]
                            cnt += 1
                else:
                    # vertical then horizontal
                    ii_s = max(x0c[i,j,0], x1c[i,j-d,0]) + 1
                    ii_t = min(x0c[i,j,1], x1c[i,j-d,1])
                    for ii in range(ii_s, ii_t):
                        jj_s = max(x0c[ii,j,2], x1c[ii,j-d,2] + d) + 1
                        jj_t = min(x0c[ii,j,3], x1c[ii,j-d,3] + d)
                        for jj in range(jj_s, jj_t):
                            sum += vol[d, ii, jj]
                            cnt += 1
                assert(cnt > 0)
                res[d, i, j] = sum / cnt
    return res


def sgm(np.ndarray[np.float64_t, ndim=3] x0,
        np.ndarray[np.float64_t, ndim=3] x1,
        np.ndarray[np.float64_t, ndim=3] vol):
    cdef np.ndarray[np.float64_t, ndim=3] res, v0, v1, v2, v3

    cdef int i, j, d
    cdef double min_curr, min_prev, P1, P2, D1, D2

    # left-right
    res = np.empty_like(vol)
    min_prev = 0
    for i in range(height):
        for j in range(width):
            min_curr = INFINITY
            for d in range(disp_max):
                if j - d - 1 < 0:
                    res[d,i,j] = vol[d,i,j]
                else:
                    D1 = max(abs(x0[i,j,0] - x0[i,j-1,0]),
                             abs(x0[i,j,1] - x0[i,j-1,1]),
                             abs(x0[i,j,2] - x0[i,j-1,2]))
                    D2 = max(abs(x1[i,j-d,0] - x1[i,j-d-1,0]),
                             abs(x1[i,j-d,1] - x1[i,j-d-1,1]),
                             abs(x1[i,j-d,2] - x1[i,j-d-1,2]))
                    if   D1 <  tau_so and D2 <  tau_so: P1, P2 = pi1,      pi2
                    elif D1 <  tau_so and D2 >= tau_so: P1, P2 = pi1 / 4,  pi2 / 4
                    elif D1 >= tau_so and D2 <  tau_so: P1, P2 = pi1 / 4,  pi2 / 4
                    else:                               P1, P2 = pi1 / 10, pi2 / 10

                    res[d,i,j] = vol[d,i,j] + min(
                        res[d,i,j-1],
                        res[d-1,i,j-1] + P1 if d-1 >= 0 else INFINITY,
                        res[d+1,i,j-1] + P1 if d+1 < disp_max else INFINITY,
                        min_prev + P2) - min_prev
                if res[d,i,j] < min_curr:
                    min_curr = res[d,i,j]
            min_prev = min_curr
    v0 = res

    # right-left
    res = np.empty_like(vol)
    for i in range(height):
        for j in range(width - 1, -1, -1):
            min_curr = INFINITY
            for d in range(disp_max):
                if j + 1 >= width or j - d < 0:
                    res[d,i,j] = vol[d,i,j]
                else:
                    D1 = max(abs(x0[i,j,0] - x0[i,j+1,0]),
                             abs(x0[i,j,1] - x0[i,j+1,1]),
                             abs(x0[i,j,2] - x0[i,j+1,2]))
                    D2 = max(abs(x1[i,j-d,0] - x1[i,j-d+1,0]),
                             abs(x1[i,j-d,1] - x1[i,j-d+1,1]),
                             abs(x1[i,j-d,2] - x1[i,j-d+1,2]))
                    if   D1 <  tau_so and D2 <  tau_so: P1, P2 = pi1, pi2
                    elif D1 <  tau_so and D2 >= tau_so: P1, P2 = pi1 / 4., pi2 / 4.
                    elif D1 >= tau_so and D2 <  tau_so: P1, P2 = pi1 / 4., pi2 / 4.
                    else:                               P1, P2 = pi1 / 10, pi2 / 10

                    res[d,i,j] = vol[d,i,j] - min_prev + min(
                        res[d,i,j+1],
                        res[d-1,i,j+1] + P1 if d-1 >= 0 else INFINITY,
                        res[d+1,i,j+1] + P1 if d+1 < disp_max else INFINITY,
                        min_prev + P2)
                if res[d,i,j] < min_curr:
                    min_curr = res[d,i,j]
            min_prev = min_curr
    v1 = res

    # up-down
    res = np.empty_like(vol)
    for j in range(width):
        for i in range(height):
            min_curr = INFINITY
            for d in range(disp_max):
                if j - d < 0 or i - 1 < 0:
                    res[d,i,j] = vol[d,i,j]
                else:
                    D1 = max(abs(x0[i,j,0] - x0[i-1,j,0]),
                             abs(x0[i,j,1] - x0[i-1,j,1]),
                             abs(x0[i,j,2] - x0[i-1,j,2]))
                    D2 = max(abs(x1[i,j-d,0] - x1[i-1,j-d,0]),
                             abs(x1[i,j-d,1] - x1[i-1,j-d,1]),
                             abs(x1[i,j-d,2] - x1[i-1,j-d,2]))
                    if   D1 <  tau_so and D2 <  tau_so: P1, P2 = pi1, pi2
                    elif D1 <  tau_so and D2 >= tau_so: P1, P2 = pi1 / 4, pi2 / 4
                    elif D1 >= tau_so and D2 <  tau_so: P1, P2 = pi1 / 4, pi2 / 4
                    else:                               P1, P2 = pi1 / 10, pi2 / 10

                    res[d,i,j] = vol[d,i,j] - min_prev + min(
                        res[d,i-1,j],
                        res[d-1,i-1,j] + P1 if d-1 >= 0 else INFINITY,
                        res[d+1,i-1,j] + P1 if d+1 < disp_max else INFINITY,
                        min_prev + P2)
                if res[d,i,j] < min_curr:
                    min_curr = res[d,i,j]
            min_prev = min_curr
    v2 = res

    # down-up
    res = np.empty_like(vol)
    for j in range(width):
        for i in range(height - 1, -1, -1):
            min_curr = INFINITY
            for d in range(disp_max):
                if j - d < 0 or i + 1 >= height:
                    res[d,i,j] = vol[d,i,j]
                else:
                    D1 = max(abs(x0[i,j,0] - x0[i+1,j,0]),
                             abs(x0[i,j,1] - x0[i+1,j,1]),
                             abs(x0[i,j,2] - x0[i+1,j,2]))
                    D2 = max(abs(x1[i,j-d,0] - x1[i+1,j-d,0]),
                             abs(x1[i,j-d,1] - x1[i+1,j-d,1]),
                             abs(x1[i,j-d,2] - x1[i+1,j-d,2]))
                    if   D1 <  tau_so and D2 <  tau_so: P1, P2 = pi1, pi2
                    elif D1 <  tau_so and D2 >= tau_so: P1, P2 = pi1 / 4, pi2 / 4
                    elif D1 >= tau_so and D2 <  tau_so: P1, P2 = pi1 / 4, pi2 / 4
                    else:                               P1, P2 = pi1 / 10, pi2 / 10

                    res[d,i,j] = vol[d,i,j] - min_prev + min(
                        res[d,i+1,j],
                        res[d-1,i+1,j] + P1 if d-1 >= 0 else INFINITY,
                        res[d+1,i+1,j] + P1 if d+1 < disp_max else INFINITY,
                        min_prev + P2)
                if res[d,i,j] < min_curr:
                    min_curr = res[d,i,j]
            min_prev = min_curr
    v3 = res

    return (v0 + v1 + v2 + v3) / 4
