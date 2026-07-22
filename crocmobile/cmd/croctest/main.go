// croctest exercises crocmobile from the command line for interop verification.
//
//	croctest send [-relay ADDR] [-no-local] [-only-local] [-text MSG] [-code CODE] [PATH...]
//	croctest receive [-relay ADDR] [-no-local] [-only-local] [-out DIR] [-answer y|n] [-yes] [-cancel-after MS] CODE
//
// Events print as lines: EVENT <kind> <payload>
package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/bakirgdev/CrocApp/crocmobile"
)

type printDelegate struct {
	answer   string
	transfer **crocmobile.Transfer
}

func (p *printDelegate) OnCodeReady(code string) { fmt.Printf("EVENT code %s\n", code) }
func (p *printDelegate) OnConnected()            { fmt.Println("EVENT connected") }
func (p *printDelegate) OnFileList(j string) {
	fmt.Printf("EVENT filelist %s\n", j)
	if *p.transfer != nil {
		(*p.transfer).Respond(p.answer == "y")
		fmt.Printf("EVENT responded %s\n", p.answer)
	}
}
func (p *printDelegate) OnProgress(j string) { fmt.Printf("EVENT progress %s\n", j) }
func (p *printDelegate) OnText(t string)     { fmt.Printf("EVENT text %s\n", t) }
func (p *printDelegate) OnDone(j string) {
	fmt.Printf("EVENT done %s\n", j)
	os.Exit(0)
}
func (p *printDelegate) OnError(m string) {
	fmt.Printf("EVENT error %s\n", m)
	os.Exit(1)
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: croctest send|receive ...")
		os.Exit(2)
	}
	mode := os.Args[1]
	fs := flag.NewFlagSet(mode, flag.ExitOnError)
	relay := fs.String("relay", "", "relay address override")
	noLocal := fs.Bool("no-local", false, "disable LAN discovery")
	onlyLocal := fs.Bool("only-local", false, "LAN only")
	text := fs.String("text", "", "send text instead of files")
	code := fs.String("code", "", "custom code phrase (send)")
	out := fs.String("out", ".", "output dir (receive)")
	answer := fs.String("answer", "y", "accept answer y|n (receive)")
	yes := fs.Bool("yes", false, "auto-accept (receive)")
	cancelAfter := fs.Int("cancel-after", 0, "cancel after N ms")
	fs.Parse(os.Args[2:])

	opts := crocmobile.NewOptions()
	if *relay != "" {
		opts.RelayAddress = *relay
		opts.RelayAddress6 = ""
	}
	opts.DisableLocal = *noLocal
	opts.OnlyLocal = *onlyLocal
	opts.Code = *code
	opts.OutDir = *out
	opts.AutoAccept = *yes

	var tr *crocmobile.Transfer
	d := &printDelegate{answer: *answer, transfer: &tr}
	var err error
	switch mode {
	case "send":
		tr, err = crocmobile.StartSend(strings.Join(fs.Args(), "\n"), *text, opts, d)
	case "receive":
		if fs.NArg() != 1 {
			fmt.Fprintln(os.Stderr, "receive needs CODE")
			os.Exit(2)
		}
		tr, err = crocmobile.StartReceive(fs.Arg(0), opts, d)
	default:
		fmt.Fprintln(os.Stderr, "unknown mode", mode)
		os.Exit(2)
	}
	if err != nil {
		fmt.Printf("EVENT error %s\n", err)
		os.Exit(1)
	}
	if *cancelAfter > 0 {
		go func() {
			time.Sleep(time.Duration(*cancelAfter) * time.Millisecond)
			tr.Cancel()
			fmt.Println("EVENT cancelled")
		}()
	}
	select {} // delegate callbacks exit the process
}
