#ifndef ANNEALING_H
#define ANNEALING_H

#include <stdint.h>

/**
 * The main method to run annealing on the given set of solutions. Operates
 * directly on the @c sol array and returns when the minimum process temperature
 * has been reached. The result of this function is the @c sol array in an order
 * that causes the @c crit function to return the lowest achievable value in the
 * course of running the algorithm.
 * 
 * @param Tstart The starting temperature of the algorithm.
 * @param Tmin The ending temperature of the algorithm. The function exits
 * whenever the temperature reached in the given iteration is lower than this
 * value.
 * @param alpha The value by which the current temperature of the process is
 * multiplied at the end of every algorithm's iteration.
 * @param sol Pointer to an array containing the elements which form the
 * solution. How these elements are evaluated is determined by the evaluation
 * function.
 * @param solsize Size of the array placed under @c sol.
 * @param crit A pointer to the solution evaluation function. This function
 * takes a pointer to the array containing the solution (the same one as @c sol)
 * and the size ( @c solsize). This function is called repeatedly in order to
 * evaluate the solution currently considered : a solution is considered better
 * by the algorithm when this function returns a lower value for it. Thus, the
 * definition of this function is dependent on the problem being solved.
 * @warning This function returns immediately if :
 * @arg @c solsize is 0, or
 * @arg @c sol is @c NULL, or
 * @arg @c crit is @c NULL, or
 * @arg @c alpha is lower than or equal to 0, or higher than or equal to 1, or
 * @arg @c Tstart is lower than or equal to 0, or
 * @arg @c Tmin is lower than or equal to 0, or
 * @arg @c Tmin is greater than @c Tstart.
 */
void annealing(float Tstart,float Tmin,float alpha,uint32_t *sol,int solsize,
    int(*crit)(const uint32_t*,int));

/**
 * Seeds for the PRNG used inside the algorithm. They need to be filled by the
 * calling application prior to calling @c annealing, or the result is
 * undefined.
 */
extern uint32_t seed[2];

#endif
