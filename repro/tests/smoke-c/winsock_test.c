/*
 * winsock_test.c
 * Winsock 网络测试 - 已有测试
 */
#include <winsock2.h>
#include <stdio.h>

#pragma comment(lib, "ws2_32.lib")

int main(void) {
    WSADATA wsaData;
    int result;
    
    /* Initialize Winsock */
    result = WSAStartup(MAKEWORD(2, 2), &wsaData);
    if (result != 0) {
        fprintf(stderr, "WSAStartup failed: %d\n", result);
        return 1;
    }
    
    printf("Winsock version: %d.%d\n", 
           LOBYTE(wsaData.wVersion), HIBYTE(wsaData.wVersion));
    printf("Winsock description: %s\n", wsaData.szDescription);
    
    /* Create a socket */
    SOCKET sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (sock == INVALID_SOCKET) {
        fprintf(stderr, "socket failed: %d\n", WSAGetLastError());
        WSACleanup();
        return 1;
    }
    
    closesocket(sock);
    WSACleanup();
    
    printf("winsock-test: PASS\n");
    return 0;
}
