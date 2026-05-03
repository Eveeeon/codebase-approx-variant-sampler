#include <stdio.h>

double add(double a, double b) {
    return a + b;
}

double multiply(double a, double b) {
    return a * b;
}

int main() {
    double x = 1.5;
    double y = 2.5;
    double result = add(x, y) * multiply(x, y);
    printf("Result: %f\n", result);
    return 0;
}