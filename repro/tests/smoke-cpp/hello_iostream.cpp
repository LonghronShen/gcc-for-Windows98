#include <iostream>
#include <string>

int main() {
    std::string target = "native iostream smoke";
    std::cout << "hello, " << target << std::endl;
    std::cerr << "cerr-ok" << std::endl;
    return 0;
}
