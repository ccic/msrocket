package main
import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"syscall"
)

type exit struct {
	pid int
	status int
}

type sigHandler struct {
	signals	chan os.Signal
}

func newExitHandler() *sigHandler {
	s := make(chan os.Signal, 2)
	signal.Notify(s)
	return &sigHandler {
		signals:	s,
	}
}

func (h *sigHandler) atExit(cmd *exec.Cmd) (int, error) {
	for s := range h.signals {
		switch s {
		case syscall.SIGCHLD:
			exits, err := h.reap()
			if err != nil {
				fmt.Println(err)
			}
			for _, e := range exits {
				fmt.Printf("child pid: %d, status: %d\n", e.pid, e.status)
				if e.pid == cmd.Process.Pid {
					// call Wait() on the process even though we already have the exit
					// status because we must ensure that any of the go specific process
					// fun such as flushing pipes are complete before we return.
					cmd.Wait()
					return e.status, nil
				}
			}
		default:
			fmt.Printf("unknown signal %s\n", s)
		}
	}
	return -1, nil
}

// reap runs wait4 in a loop until we have finished processing any existing exits
// then returns all exits to the main event loop for further processing.
func (h *sigHandler) reap() (exits []exit, err error) {
	var (
		ws  syscall.WaitStatus
		rus syscall.Rusage
	)
	for {
		pid, err := syscall.Wait4(-1, &ws, syscall.WNOHANG, &rus)
		if err != nil {
			if err == syscall.ECHILD {
				return exits, nil
			}
			return nil, err
		}
		if pid <= 0 {
			return exits, nil
		}
		exits = append(exits, exit{
			pid:    pid,
			status: exitStatus(ws),
		})
	}
}

func exitStatus(status syscall.WaitStatus) int {
	if status.Signaled() {
		return 128 + int(status.Signal())
	}
	return status.ExitStatus()
}

func runChildProcess(name string, arg... string) (int, error) {
	cmd := exec.Command(name, arg...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	hdl := newExitHandler()

	if err := cmd.Start(); err != nil {
		return -1, err
	}

	return hdl.atExit(cmd) // hang until the command finishes
}

func main() {
	fmt.Printf("main pid: %d\n", syscall.Getpid())
	s, err := runChildProcess("/bin/sh")
	if err != nil {
		fmt.Println(err)
	}
	fmt.Printf("exit status: %d\n", s)
}
