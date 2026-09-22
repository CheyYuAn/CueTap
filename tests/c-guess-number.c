#include <stdio.h>
#include <stdlib.h>
#include <time.h>
int main(void) {
    srand(time(NULL)); int secret = rand() % 100 + 1, guess, n = 0;
    do { printf("Guess 1-100: "); scanf("%d", &guess); n++;
        if (guess != secret) printf(guess < secret ? "Too low\n" : "Too high\n");
    } while (guess != secret);
    printf("Correct! %d tries\n", n); return 0;
}
