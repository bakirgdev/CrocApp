// croctest exercises crocmobile from the command line for interop verification.
//
//	croctest send [-relay ADDR] [-no-local] [-only-local] [-text MSG] [-code CODE] [-relay-index N] [-throttle RATE] [-no-multi] [-transport auto|relay|derp] [ADVANCED] [PATH...]
//	croctest receive [-relay ADDR] [-no-local] [-only-local] [-out DIR] [-answer y|n] [-yes] [-policy keepBoth|replace] [-cancel-after MS] [ADVANCED] CODE
//	croctest store-send [-server URL] [-downloads N] [-lifetime SECONDS] [-socks5 ADDR] [-connect ADDR] PATH...
//	croctest store-receive [-out DIR] [-answer y|n] [-policy keepBoth|replace] [-cancel-after MS] [-socks5 ADDR] [-connect ADDR] LINK
//	croctest store-revoke [-socks5 ADDR] [-connect ADDR] ORIGIN ID TOKEN
//	croctest store-server DIR
//	croctest socks5-proxy
//	croctest http-proxy
//	croctest multicast-listen GROUP SECONDS
//	croctest relay CODE
//	croctest relays
//
// -throttle caps the sender's upload rate (e.g. "200k", "1m") so cancel
// timing in a slow/fast test environment can be made deterministic instead
// of racing a transfer that may already be finished.
//
// -policy is what a receive does with a file whose name already exists: on the
// Options for -yes, in the accept answer otherwise.
//
// -transport is the sender's data transport; croc's "derp" forces Tailcat with
// no relay fallback.
//
// ADVANCED are the Options of the app's Advanced settings, named like croc's
// own flags: -curve, -hash, -port, -transfers, -multicast, -ip, -socks5,
// -connect, -internal-dns.
//
// socks5-proxy and http-proxy run a CONNECT-only proxy without authentication
// on a loopback port for the harness, and print "PROXY-ADDR <host:port>" once
// it listens and "PROXY-TUNNEL <target>" for each connection it tunnels. croc's
// dialer bypasses proxies for local addresses, so a tunnel appears only for a
// non-local relay such as the public pool.
//
// multicast-listen joins the multicast GROUP on discovery's port for SECONDS
// seconds and prints "MULTICAST-LISTEN <interfaces joined>", then one
// "MULTICAST-PAYLOAD <text>" per datagram. A croc sender announces "croc<port>"
// and a receiver "ok". croc drops discovery packets from the machine's own
// addresses, so on one host this is the only way to see the group in use.
//
// -relay-index makes a generated code map to that public pool relay, as if the
// latency probe had picked it. relay prints the pool relay a code maps to;
// relays prints the pool in index order.
//
// The store modes use a stored-transfer server (default https://getcroc.com).
// store-server runs croc's own server on a loopback port for the harness,
// storing in DIR, and prints "STORE-URL <origin>" once it listens.
// store-send prints EVENT stored with the receipt JSON, whose link and
// uploadToken are secrets; store-receive answers the preview like receive does.
//
// Events print as lines: EVENT <kind> <payload>. With the public pool in use,
// EVENT relay names the relay the code maps to.
package main

import (
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/bakirgdev/CrocApp/crocmobile"
	"github.com/bakirgdev/CrocApp/crocmobile/internal/relaycache"
	"github.com/schollz/croc/v11/src/publicrelay"
	"github.com/schollz/croc/v11/src/store"
)

type printDelegate struct {
	answer   string
	policy   string
	pool     bool
	transfer **crocmobile.Transfer
	ready    chan struct{} // closed once *transfer is set, so a fast OnFileList can respond
}

// Events print to stderr, not stdout: crocmobile's receive session swaps the
// process-global os.Stdout for the whole transfer to capture croc's own
// fmt.Print of a received text payload (see session.go). Printing events to
// stdout here would race that swap and vanish into the capture buffer instead
// of reaching this process's actual output.
func (p *printDelegate) OnCodeReady(code string) {
	fmt.Fprintf(os.Stderr, "EVENT code %s\n", code)
	if p.pool {
		printRelay(code)
	}
}
func (p *printDelegate) OnConnected() { fmt.Fprintln(os.Stderr, "EVENT connected") }
func (p *printDelegate) OnFileList(j string) {
	fmt.Fprintf(os.Stderr, "EVENT filelist %s\n", j)
	<-p.ready
	if *p.transfer != nil {
		(*p.transfer).Respond(p.answer == "y", p.policy)
		fmt.Fprintf(os.Stderr, "EVENT responded %s %s\n", p.answer, p.policy)
	}
}
func (p *printDelegate) OnProgress(j string) { fmt.Fprintf(os.Stderr, "EVENT progress %s\n", j) }
func (p *printDelegate) OnText(t string)     { fmt.Fprintf(os.Stderr, "EVENT text %s\n", t) }
func (p *printDelegate) OnDone(j string) {
	fmt.Fprintf(os.Stderr, "EVENT done %s\n", j)
	os.Exit(0)
}
func (p *printDelegate) OnStored(j string) { fmt.Fprintf(os.Stderr, "EVENT stored %s\n", j) }
func (p *printDelegate) OnError(m string) {
	fmt.Fprintf(os.Stderr, "EVENT error %s\n", m)
	os.Exit(1)
}

// serveStore never returns. The limits are lifted far enough for the harness
// to ask for several downloads; the rate limit would otherwise trip on a run
// that revokes and re-uploads.
func serveStore(dir string) {
	svc, err := store.New(store.Config{
		Root: dir, MaxDownloads: 100, MinFreeBytes: 1, CreatePerHour: 1000, MaxActiveUploads: 10, DisableRootLock: true,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "EVENT error %s\n", err)
		os.Exit(1)
	}
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fmt.Fprintf(os.Stderr, "EVENT error %s\n", err)
		os.Exit(1)
	}
	fmt.Fprintf(os.Stderr, "STORE-URL http://%s\n", l.Addr())
	fmt.Fprintf(os.Stderr, "EVENT error %s\n", http.Serve(l, svc))
	os.Exit(1)
}

func printRelay(code string) {
	fmt.Fprintf(os.Stderr, "EVENT relay %s\n", crocmobile.RelayForCode(code))
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: croctest send|receive|store-send|store-receive|store-revoke|store-server|socks5-proxy|http-proxy|multicast-listen|relay|relays ...")
		os.Exit(2)
	}
	mode := os.Args[1]
	switch mode {
	case "relay":
		if len(os.Args) != 3 {
			fmt.Fprintln(os.Stderr, "relay needs CODE")
			os.Exit(2)
		}
		fmt.Println(crocmobile.RelayForCode(os.Args[2]))
		return
	case "store-server":
		if len(os.Args) != 3 {
			fmt.Fprintln(os.Stderr, "store-server needs DIR")
			os.Exit(2)
		}
		serveStore(os.Args[2])
		return
	case "socks5-proxy":
		serveSocks5()
		return
	case "http-proxy":
		serveHTTPProxy()
		return
	case "multicast-listen":
		secs, err := strconv.Atoi(os.Args[len(os.Args)-1])
		if len(os.Args) != 4 || err != nil {
			fmt.Fprintln(os.Stderr, "multicast-listen needs GROUP SECONDS")
			os.Exit(2)
		}
		listenMulticast(os.Args[2], time.Duration(secs)*time.Second)
		return
	case "relays":
		for _, r := range publicrelay.Relays() {
			fmt.Println(r)
		}
		return
	}
	fs := flag.NewFlagSet(mode, flag.ExitOnError)
	server := fs.String("server", "https://getcroc.com", "stored-transfer server (store-send)")
	downloads := fs.Int("downloads", 1, "downloads allowed (store-send)")
	lifetime := fs.Int("lifetime", 3600, "storage lifetime in seconds (store-send)")
	relay := fs.String("relay", "", "relay address override")
	noLocal := fs.Bool("no-local", false, "disable LAN discovery")
	onlyLocal := fs.Bool("only-local", false, "LAN only")
	text := fs.String("text", "", "send text instead of files")
	code := fs.String("code", "", "custom code phrase (send)")
	out := fs.String("out", ".", "output dir (receive)")
	answer := fs.String("answer", "y", "accept answer y|n (receive)")
	yes := fs.Bool("yes", false, "auto-accept (receive)")
	policy := fs.String("policy", crocmobile.PolicyKeepBoth, "existing file: keepBoth|replace (receive)")
	cancelAfter := fs.Int("cancel-after", 0, "cancel after N ms")
	throttle := fs.String("throttle", "", "cap sender upload rate, e.g. 200k, 1m (send)")
	relayIndex := fs.Int("relay-index", -1, "public pool relay a generated code maps to (send)")
	noMulti := fs.Bool("no-multi", false, "one data connection instead of one per relay port (send)")
	transport := fs.String("transport", crocmobile.TransportAuto, "data transport: auto|relay|derp (send)")
	curve := fs.String("curve", "p256", "PAKE curve")
	hash := fs.String("hash", "xxhash", "file hash algorithm (send)")
	port := fs.Int("port", crocmobile.DefaultBasePort, "base port of the local relay (send)")
	transfers := fs.Int("transfers", crocmobile.DefaultTransfers, "data ports after the base port (send)")
	multicast := fs.String("multicast", crocmobile.DefaultMulticastAddress, "multicast address for LAN discovery")
	peerIP := fs.String("ip", "", "sender ip:port, skipping relays (receive)")
	socks5 := fs.String("socks5", "", "SOCKS5 proxy")
	connect := fs.String("connect", "", "HTTP proxy")
	internalDNS := fs.Bool("internal-dns", false, "croc's built-in DNS resolver")
	_ = fs.Parse(os.Args[2:])

	if *policy != crocmobile.PolicyKeepBoth && *policy != crocmobile.PolicyReplace {
		fmt.Fprintln(os.Stderr, "-policy must be keepBoth or replace")
		os.Exit(2)
	}
	if *relayIndex >= 0 {
		relaycache.Set(*relayIndex)
	}

	opts := crocmobile.NewOptionsDefault()
	if *relay != "" {
		opts.RelayAddress = *relay
		opts.RelayAddress6 = ""
	}
	opts.DisableLocal = *noLocal
	opts.OnlyLocal = *onlyLocal
	opts.Code = *code
	opts.OutDir = *out
	opts.AutoAccept = *yes
	// Without -yes the Options stay at Keep Both, as in the app, so a Replace
	// answer proves the policy sent at accept time reaches croc.
	if *yes {
		opts.Overwrite = *policy == crocmobile.PolicyReplace
		opts.Rename = !opts.Overwrite
	} else {
		opts.Rename = true
	}
	opts.ThrottleUpload = *throttle
	opts.NoMultiplexing = *noMulti
	opts.Transport = *transport
	opts.Curve = *curve
	opts.HashAlgorithm = *hash
	opts.BasePort = *port
	opts.Transfers = *transfers
	opts.MulticastAddress = *multicast
	opts.PeerIP = *peerIP
	opts.Socks5Proxy = *socks5
	opts.HTTPProxy = *connect
	opts.InternalDNS = *internalDNS
	proxies := &crocmobile.StoreOptions{Socks5Proxy: *socks5, HTTPProxy: *connect}

	var tr *crocmobile.Transfer
	d := &printDelegate{answer: *answer, policy: *policy, pool: *relay == "" && !*onlyLocal && *peerIP == "", transfer: &tr, ready: make(chan struct{})}
	var err error
	switch mode {
	case "store-send":
		tr, err = crocmobile.StartStoreSend(strings.Join(fs.Args(), "\n"),
			&crocmobile.StoreOptions{Server: *server, Downloads: *downloads, LifetimeSeconds: *lifetime, Socks5Proxy: *socks5, HTTPProxy: *connect}, d)
	case "store-receive":
		if fs.NArg() != 1 {
			fmt.Fprintln(os.Stderr, "store-receive needs LINK")
			os.Exit(2)
		}
		tr, err = crocmobile.StartStoreReceive(fs.Arg(0), *out, proxies, d)
	case "store-revoke":
		if fs.NArg() != 3 {
			fmt.Fprintln(os.Stderr, "store-revoke needs ORIGIN ID TOKEN")
			os.Exit(2)
		}
		if err := crocmobile.RevokeStored(fs.Arg(0), fs.Arg(1), fs.Arg(2), proxies); err != nil {
			fmt.Fprintf(os.Stderr, "EVENT error %s\n", err)
			os.Exit(1)
		}
		fmt.Fprintln(os.Stderr, "EVENT revoked")
		return
	case "send":
		tr, err = crocmobile.StartSend(strings.Join(fs.Args(), "\n"), *text, opts, d)
	case "receive":
		if fs.NArg() != 1 {
			fmt.Fprintln(os.Stderr, "receive needs CODE")
			os.Exit(2)
		}
		if d.pool {
			printRelay(fs.Arg(0))
		}
		tr, err = crocmobile.StartReceive(fs.Arg(0), opts, d)
	default:
		fmt.Fprintln(os.Stderr, "unknown mode", mode)
		os.Exit(2)
	}
	close(d.ready)
	if err != nil {
		fmt.Fprintf(os.Stderr, "EVENT error %s\n", err)
		os.Exit(1)
	}
	if *cancelAfter > 0 {
		go func() {
			time.Sleep(time.Duration(*cancelAfter) * time.Millisecond)
			tr.Cancel()
			fmt.Fprintln(os.Stderr, "EVENT cancelled")
		}()
	}
	select {} // delegate callbacks exit the process
}
