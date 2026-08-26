import socket
import threading
import sys

LOCAL_HOST = "127.0.0.1"
LOCAL_PORT = 8443
SOCKS_HOST = "127.0.0.1"
SOCKS_PORT = 40000

def parse_sni(data):
    try:
        # Check for TLS Handshake (0x16) and Version (0x03)
        if len(data) < 5 or data[0] != 0x16 or data[1] != 0x03:
            return None
        
        # Client Hello is handshake type 1
        pos = 5
        if pos >= len(data) or data[pos] != 0x01:
            return None
        
        # Length of Client Hello (3 bytes)
        pos += 4
        # TLS Version (2 bytes)
        pos += 2
        # Random (32 bytes)
        pos += 32
        
        # Session ID Length (1 byte) + Session ID
        if pos >= len(data): return None
        session_id_len = data[pos]
        pos += 1 + session_id_len
        
        # Cipher Suites Length (2 bytes) + Cipher Suites
        if pos + 2 > len(data): return None
        cipher_suites_len = int.from_bytes(data[pos:pos+2], 'big')
        pos += 2 + cipher_suites_len
        
        # Compression Methods Length (1 byte) + Compression Methods
        if pos >= len(data): return None
        compression_len = data[pos]
        pos += 1 + compression_len
        
        # Extensions Length (2 bytes)
        if pos + 2 > len(data): return None
        extensions_len = int.from_bytes(data[pos:pos+2], 'big')
        pos += 2
        
        end_pos = pos + extensions_len
        
        # Parse Extensions
        while pos + 4 <= end_pos and pos + 4 <= len(data):
            ext_type = int.from_bytes(data[pos:pos+2], 'big')
            ext_len = int.from_bytes(data[pos+2:pos+4], 'big')
            pos += 4
            
            # Extension type 0 is server_name (SNI)
            if ext_type == 0:
                sni_pos = pos
                if sni_pos + 2 > len(data): return None
                server_name_list_len = int.from_bytes(data[sni_pos:sni_pos+2], 'big')
                sni_pos += 2
                
                if sni_pos >= len(data): return None
                name_type = data[sni_pos]
                if sni_pos + 3 > len(data): return None
                name_len = int.from_bytes(data[sni_pos+1:sni_pos+3], 'big')
                sni_pos += 3
                
                if name_type == 0 and sni_pos + name_len <= len(data):
                    return data[sni_pos:sni_pos+name_len].decode('utf-8')
            pos += ext_len
    except Exception:
        pass
    return None

def tunnel(source, destination):
    try:
        while True:
            data = source.recv(16384)
            if not data:
                break
            destination.sendall(data)
    except Exception:
        pass
    finally:
        try: source.close()
        except Exception: pass
        try: destination.close()
        except Exception: pass

def handle_client(client_socket):
    try:
        # Read the first packet (TLS ClientHello)
        client_hello = client_socket.recv(4096)
        if not client_hello:
            client_socket.close()
            return
            
        # Parse SNI host
        target_host = parse_sni(client_hello)
        if not target_host:
            # Fallback to www.youtube.com if SNI parsing fails
            target_host = "www.youtube.com"
            
        target_port = 443
        
        # Connect to SOCKS5 proxy
        socks_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        socks_socket.settimeout(10)
        socks_socket.connect((SOCKS_HOST, SOCKS_PORT))
        
        # SOCKS5 greeting
        socks_socket.sendall(b"\x05\x01\x00")
        resp = socks_socket.recv(2)
        if len(resp) != 2 or resp[0] != 5 or resp[1] != 0:
            client_socket.close()
            socks_socket.close()
            return
            
        # Connect to target via SOCKS5
        host_bytes = target_host.encode('utf-8')
        port_bytes = target_port.to_bytes(2, 'big')
        req = b"\x05\x01\x00\x03" + len(host_bytes).to_bytes(1, 'big') + host_bytes + port_bytes
        socks_socket.sendall(req)
        
        resp = socks_socket.recv(10)
        if len(resp) < 4 or resp[0] != 5 or resp[1] != 0:
            client_socket.close()
            socks_socket.close()
            return
            
        # SOCKS5 connection established. Send the cached ClientHello
        socks_socket.sendall(client_hello)
        
        # Start bidirectional tunneling
        t1 = threading.Thread(target=tunnel, args=(client_socket, socks_socket))
        t2 = threading.Thread(target=tunnel, args=(socks_socket, client_socket))
        t1.daemon = True
        t2.daemon = True
        t1.start()
        t2.start()
    except Exception:
        try: client_socket.close()
        except Exception: pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((LOCAL_HOST, LOCAL_PORT))
    server.listen(200)
    print(f"SNI SOCKS5 Forwarder listening on {LOCAL_HOST}:{LOCAL_PORT}...", flush=True)
    
    try:
        while True:
            client_sock, addr = server.accept()
            t = threading.Thread(target=handle_client, args=(client_sock,))
            t.daemon = True
            t.start()
    except KeyboardInterrupt:
        pass
    finally:
        server.close()

if __name__ == "__main__":
    main()
