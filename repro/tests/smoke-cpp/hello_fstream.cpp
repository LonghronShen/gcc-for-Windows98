#include <fstream>
#include <iostream>
#include <string>

int main() {
    const std::string path = "fstream_smoke.txt";
    const std::string expected = "fstream-ok";

    {
        std::ofstream out(path, std::ios::binary);
        if(!out) {
            std::cerr << "open-write-failed" << std::endl;
            return 2;
        }
        out << expected;
        if(!out.good()) {
            std::cerr << "write-failed" << std::endl;
            return 3;
        }
    }

    std::ifstream in(path, std::ios::binary);
    if(!in) {
        std::cerr << "open-read-failed" << std::endl;
        return 4;
    }

    std::string actual;
    std::getline(in, actual);
    if(actual != expected) {
        std::cerr << "mismatch:" << actual << std::endl;
        return 5;
    }

    std::cout << "fstream-ok" << std::endl;
    return 0;
}
