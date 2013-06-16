#include <stdio.h>
#include <stdint.h>
#include <sys/time.h>
#include "annealing.h"

/* gr17.tsp, the smallest Travelling Salesman Problem instance from a set of
 * example instances found somewhere on the net. As far as I remember, the
 * optimal solution's cost is 2085. */
uint32_t cost_table[][17] = {
    { 0 },
    { 633, 0 },
    { 257, 390, 0 },
    { 91, 661, 228, 0 },
    { 412, 227, 169, 383, 0 },
    { 150, 488, 112, 120, 267, 0 },
    { 80, 572, 196, 77, 351, 63, 0 },
    { 134, 530, 154, 105, 309, 34, 29, 0 },
    { 259, 555, 372, 175, 338, 264, 232, 249, 0 },
    { 505, 289, 262, 476, 196, 360, 444, 402, 495, 0 },
    { 353, 282, 110, 324, 61, 208, 292, 250, 352, 154, 0 },
    { 324, 638, 437, 240, 421, 329, 297, 314, 95, 578, 435, 0 },
    { 70, 567, 191, 27, 346, 83, 47, 68, 189, 439, 287, 254, 0 },
    { 211, 466, 74, 182, 243, 105, 150, 108, 326, 336, 184, 391, 145, 0 },
    { 268, 420, 53, 239, 199, 123, 207, 165, 383, 240, 140, 448, 202, 57, 0 },
    { 246, 745, 472, 237, 528, 364, 332, 349, 202, 685, 542, 157, 289, 426, 483, 0 },
    { 121, 518, 142, 84, 297, 35, 29, 36, 236, 390, 238, 301, 55, 96, 153, 336, 0 } 
};

int crit_function(const uint32_t *cities,int cities_num)
{
    /* calculate the cost of visiting the given sequence of cities by querying
     * the cost table. */
    int i,sum=0,min_city,max_city;
    for(i=0;i<cities_num-1;++i)
    {
        min_city = (cities[i] < cities[i+1]) ? cities[i] : cities[i+1];
        max_city = (cities[i] > cities[i+1]) ? cities[i] : cities[i+1];
        sum += cost_table[max_city][min_city];
    }
    min_city = (cities[cities_num-1] < cities[0]) ? cities[cities_num-1] : cities[0];
    max_city = (cities[cities_num-1] > cities[0]) ? cities[cities_num-1] : cities[0];
    sum += cost_table[max_city][min_city];
    return sum;
}

#define SIZE(x) ((sizeof(x))/(sizeof(*x)))

int main(void)
{
    struct timeval a;
    size_t i;
    /* the starting solution for the problem. */
    uint32_t cities[] =
    { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    
    gettimeofday(&a,NULL);
    seed[0] = a.tv_sec;
    seed[1] = a.tv_usec;
    
    annealing(100000,1,0.99,cities,SIZE(cities),crit_function);
    
    for(i=0;i<SIZE(cities);++i)
    {
        printf("%d ",cities[i]);
    }
    printf("\n%d\n",crit_function(cities,SIZE(cities)));
    
    return 0;
}

#undef SIZE
