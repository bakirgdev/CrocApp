package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"
)

// The proxy modes let the harness prove that crocmobile's -socks5 and -connect
// reach croc's dialer. Both do CONNECT only, with no authentication, listen on
// loopback, print "PROXY-ADDR <host:port>" once they listen and one
// "PROXY-TUNNEL <target>" per connection they tunnel, to stderr.

func listenProxy() net.Listener {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fmt.Fprintf(os.Stderr, "EVENT error %s\n", err)
		os.Exit(1)
	}
	fmt.Fprintf(os.Stderr, "PROXY-ADDR %s\n", l.Addr())
	return l
}

func tunnel(client net.Conn, target string, ready func() error) {
	defer client.Close()
	remote, err := net.DialTimeout("tcp", target, 15*time.Second)
	if err != nil {
		return
	}
	defer remote.Close()
	if ready() != nil {
		return
	}
	fmt.Fprintf(os.Stderr, "PROXY-TUNNEL %s\n", target)
	var wg sync.WaitGroup
	wg.Add(2)
	pipe := func(dst, src net.Conn) {
		defer wg.Done()
		_, _ = io.Copy(dst, src)
		// Pass the half-close on, so the opposite copy ends once its peer
		// has sent everything.
		if cw, ok := dst.(interface{ CloseWrite() error }); ok {
			_ = cw.CloseWrite()
		} else {
			_ = dst.Close()
		}
	}
	go pipe(remote, client)
	go pipe(client, remote)
	wg.Wait()
}

func serveSocks5() {
	l := listenProxy()
	for {
		c, err := l.Accept()
		if err != nil {
			fmt.Fprintf(os.Stderr, "EVENT error %s\n", err)
			os.Exit(1)
		}
		go handleSocks5(c)
	}
}

func handleSocks5(c net.Conn) {
	target, err := socks5Handshake(c)
	if err != nil {
		c.Close()
		return
	}
	tunnel(c, target, func() error {
		_, err := c.Write([]byte{5, 0, 0, 1, 0, 0, 0, 0, 0, 0})
		return err
	})
}

// socks5Handshake reads a no-auth greeting and a CONNECT request and returns
// the target as host:port.
func socks5Handshake(c net.Conn) (string, error) {
	_ = c.SetDeadline(time.Now().Add(15 * time.Second))
	defer func() { _ = c.SetDeadline(time.Time{}) }()
	head := make([]byte, 2)
	if _, err := io.ReadFull(c, head); err != nil || head[0] != 5 {
		return "", errors.New("not socks5")
	}
	if _, err := io.ReadFull(c, make([]byte, head[1])); err != nil {
		return "", err
	}
	if _, err := c.Write([]byte{5, 0}); err != nil {
		return "", err
	}
	req := make([]byte, 4)
	if _, err := io.ReadFull(c, req); err != nil || req[0] != 5 || req[1] != 1 {
		return "", errors.New("not a CONNECT request")
	}
	var host string
	switch req[3] {
	case 1, 4:
		ip := make([]byte, map[byte]int{1: 4, 4: 16}[req[3]])
		if _, err := io.ReadFull(c, ip); err != nil {
			return "", err
		}
		host = net.IP(ip).String()
	case 3:
		n := make([]byte, 1)
		if _, err := io.ReadFull(c, n); err != nil {
			return "", err
		}
		name := make([]byte, n[0])
		if _, err := io.ReadFull(c, name); err != nil {
			return "", err
		}
		host = string(name)
	default:
		return "", errors.New("unknown address type")
	}
	port := make([]byte, 2)
	if _, err := io.ReadFull(c, port); err != nil {
		return "", err
	}
	return net.JoinHostPort(host, strconv.Itoa(int(binary.BigEndian.Uint16(port)))), nil
}

func serveHTTPProxy() {
	l := listenProxy()
	fmt.Fprintf(os.Stderr, "EVENT error %s\n", http.Serve(l, http.HandlerFunc(handleConnect)))
	os.Exit(1)
}

func handleConnect(w http.ResponseWriter, r *http.Request) {
	hj, ok := w.(http.Hijacker)
	if r.Method != http.MethodConnect || !ok {
		http.Error(w, "CONNECT only", http.StatusMethodNotAllowed)
		return
	}
	c, _, err := hj.Hijack()
	if err != nil {
		return
	}
	tunnel(c, r.Host, func() error {
		_, err := c.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))
		return err
	})
}
