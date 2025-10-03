#include <iostream>
#include "math.h"

int main() {
    int a = 5, b = 3;
    std::cout << "Calculator using math library:" << std::endl;
    std::cout << a << " + " << b << " = " << add(a, b) << std::endl;
    std::cout << a << " * " << b << " = " << multiply(a, b) << std::endl;
    return 0;
}