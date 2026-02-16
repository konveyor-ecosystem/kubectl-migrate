package utils

import (
    "bytes"
    "fmt"
    "os/exec"
    "strings"
)

// CommandResult holds the result of a command execution
type CommandResult struct {
    Stdout   string
    Stderr   string
    ExitCode int
    Error    error
}

// RunCommand executes a shell command and returns the result
func RunCommand(name string, args ...string) CommandResult {
    cmd := exec.Command(name, args...)
    
    var stdout, stderr bytes.Buffer
    cmd.Stdout = &stdout
    cmd.Stderr = &stderr
    
    err := cmd.Run()
    
    result := CommandResult{
        Stdout: strings.TrimSpace(stdout.String()),
        Stderr: strings.TrimSpace(stderr.String()),
    }
    
    if err != nil {
        result.Error = err
        if exitErr, ok := err.(*exec.ExitError); ok {
            result.ExitCode = exitErr.ExitCode()
        } else {
            result.ExitCode = -1
        }
    } else {
        result.ExitCode = 0
    }
    
    return result
}

// RunKubectl is a convenience wrapper for kubectl commands
func RunKubectl(args ...string) CommandResult {
    return RunCommand("kubectl", args...)
}

// Success checks if the command executed successfully
func (r CommandResult) Success() bool {
    return r.ExitCode == 0 && r.Error == nil
}

// String returns a formatted string representation
func (r CommandResult) String() string {
    return fmt.Sprintf("Exit Code: %d\nStdout: %s\nStderr: %s\nError: %v",
        r.ExitCode, r.Stdout, r.Stderr, r.Error)
}