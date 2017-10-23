# Copyright (C) 2014 Linaro Limited
#
# Author: Neil Williams <neil.williams@linaro.org>
#
# This file is part of LAVA Dispatcher.
#
# LAVA Dispatcher is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# LAVA Dispatcher is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along
# with this program; if not, see <http://www.gnu.org/licenses>.

import logging
import contextlib
import logging
import pexpect
import sys
import time
import subprocess

LINE_SEPARATOR = '\n'
ACTION_TIMEOUT = 30
OVERRIDE_CLAMP_DURATION = 300

def seconds_to_str(time):
    hours, remainder = divmod(int(round(time)), 3600)
    minutes, seconds = divmod(remainder, 60)
    return "%02d:%02d:%02d" % (hours, minutes, seconds)

class Connection(object):
    """
    A raw_connection is an arbitrary instance of a standard Python (or added LAVA) class
    designed to implement an interactive connection onto the device. The raw_connection
    needs to be able to send commands, use a timeout, handle errors, log the output,
    match on regular expressions for the output, report the pid of the spawned process
    and cause the spawned process to close/terminate.
    The current implementation uses a pexpect.spawn wrapper. For a standard Shell
    connection, that is the ShellCommand class.
    Each different wrapper of pexpect.spawn (and any other wrappers later designed)
    needs to be a separate class supported by another class inheriting from Connection.

    Connecting between devices is handled inside the YAML test definition, whether by
    multinode or by configured services inside the test image.
    """
    def __init__(self, raw_connection):
        self.raw_connection = raw_connection
        self.results = {}
        self.match = None
        self.connected = True
        self.check_char = '#'

    def corruption_check(self):
        self.sendline(self.check_char)

    def sendline(self, line, delay=0, disconnecting=False):
        if self.connected:
            self.raw_connection.sendline(line, delay=delay)
        elif not disconnecting:
            print("sendline")
            exit(-1)

    def sendcontrol(self, char):
        if self.connected:
            self.raw_connection.sendcontrol(char)
        else:
            print("sendcontrol")
            exit(-1)

    def force_prompt_wait(self, remaining):
        print("'force_prompt_wait' not implemented")
        exit(-1)

    def wait(self, max_end_time=None):
        print("'wait' not implemented")
        exit(-1)

    def disconnect(self, reason):
        print("'disconnect' not implemented")
        exit(-1)

    def finalise(self):
        if self.raw_connection:
            try:
                os.killpg(self.raw_connection.pid, signal.SIGKILL)
                # self.logger.debug("Finalizing child process group with PID %d" % self.raw_connection.pid)
            except OSError:
                self.raw_connection.kill(9)
                # self.logger.debug("Finalizing child process with PID %d" % self.raw_connection.pid)
            self.raw_connection.close()

class ShellLogger(object):
    """
    Builds a YAML log message out of the incremental output of the pexpect.spawn
    using the logfile support built into pexpect.
    """
    def __init__(self, logger):
        self.line = ''
        self.logger = logger
        self.is_feedback = False

    def write(self, new_line):
        replacements = {
            '\n\n': '\n',  # double lines to single
            '\r': '',
            '"': '\\\"',  # escape double quotes for YAML syntax
            '\x1b': ''  # remove escape control characters
        }
        for key, value in replacements.items():
            new_line = new_line.replace(key, value)
        lines = self.line + new_line

        # Print one full line at a time. A partial line is kept in memory.
        if '\n' in lines:
            last_ret = lines.rindex('\n')
            self.line = lines[last_ret + 1:]
            lines = lines[:last_ret]
            for line in lines.split('\n'):
                if self.is_feedback:
                    self.logger.info("feedback : " + line)
                else:
                    self.logger.info("target : " + line)
        else:
            self.line = lines
        return

    def flush(self):  # pylint: disable=no-self-use
        sys.stdout.flush()
        sys.stderr.flush()


class ShellCommand(pexpect.spawn):  # pylint: disable=too-many-public-methods
    """
    Run a command over a connection using pexpect instead of
    subprocess, i.e. not on the dispatcher itself.
    Takes a Timeout object (to support overrides and logging)

    A ShellCommand is a raw_connection for a ShellConnection instance.
    """

    def __init__(self, command, lava_timeout, logger=None, cwd=None):
        if not lava_timeout or not isinstance(lava_timeout, Timeout):
            print("ShellCommand needs a timeout set by the calling Action")
            exit(-1)
        if not logger:
            print("ShellCommand needs a logger")
            exit(-1)
        pexpect.spawn.__init__(
            self, command,
            timeout=lava_timeout.duration,
            cwd=cwd,
            logfile=ShellLogger(logger),
        )
        self.name = "ShellCommand"
        self.logger = logger
        # set a default newline character, but allow actions to override as neccessary
        self.linesep = LINE_SEPARATOR
        self.lava_timeout = lava_timeout

    def sendline(self, s='', delay=0):  # pylint: disable=arguments-differ
        """
        Extends pexpect.sendline so that it can support the delay argument which allows a delay
        between sending each character to get around slow serial problems (iPXE).
        pexpect sendline does exactly the same thing: calls send for the string then os.linesep.

        :param s: string to send
        :param delay: delay in milliseconds between sending each character
        """
        send_char = False
        if delay > 0:
            self.logger.debug("Sending with %s millisecond of delay", delay)
            send_char = True
        # self.logger.input(s + self.linesep)
        self.logger.info("input : " + s + self.linesep)
        self.send(s, delay, send_char)
        self.send(self.linesep, delay)

    def sendcontrol(self, char):
        # self.logger.input(char)
        self.logger.info("input : " + char)
        return super(ShellCommand, self).sendcontrol(char)

    def send(self, string, delay=0, send_char=True):  # pylint: disable=arguments-differ
        """
        Extends pexpect.send to support extra arguments, delay and send by character flags.
        """
        sent = 0
        if not string:
            return sent
        delay = float(delay) / 1000
        if send_char:
            for char in string:
                sent += super(ShellCommand, self).send(char)
                time.sleep(delay)
        else:
            sent = super(ShellCommand, self).send(string)
        return sent

    def expect(self, *args, **kw):
        """
        No point doing explicit logging here, the SignalDirector can help
        the TestShellAction make much more useful reports of what was matched
        """
        try:
            proc = super(ShellCommand, self).expect(*args, **kw)
        except pexpect.TIMEOUT:
            print("ShellCommand command timed out.")
            exit(-1)
        except ValueError as exc:
            print "error : value error"
            exit(-1)
        except pexpect.EOF:
            # FIXME: deliberately closing the connection (and starting a new one) needs to be supported.
            print "error : pexpect eof"
            exit(-1)
        return proc

    def empty_buffer(self):
        """Make sure there is nothing in the pexpect buffer."""
        index = 0
        while index == 0:
            index = self.expect(['.+', pexpect.EOF, pexpect.TIMEOUT], timeout=1)


class ShellSession(Connection):
    def __init__(self, shell_command):
        """
        A ShellSession monitors a pexpect connection.
        Optionally, a prompt can be forced after
        a percentage of the timeout.
        """
        super(ShellSession, self).__init__(shell_command)
        self.name = "ShellSession"
        # FIXME: rename __prompt_str__ to indicate it can be a list or str
        self.__prompt_str__ = None
        self.spawn = shell_command
        self.__runner__ = None
        self.timeout = shell_command.lava_timeout

    def disconnect(self, reason):
        # FIXME
        pass

    # FIXME: rename prompt_str to indicate it can be a list or str
    @property
    def prompt_str(self):
        return self.__prompt_str__

    @prompt_str.setter
    def prompt_str(self, string):
        # FIXME: Debug logging should show whenever this property is changed
        self.__prompt_str__ = string

    @contextlib.contextmanager
    def test_connection(self):
        """
        Yields the actual connection which can be used to interact inside this shell.
        """
        yield self.raw_connection

    def force_prompt_wait(self, remaining=None):
        """
        One of the challenges we face is that kernel log messages can appear
        half way through a shell prompt.  So, if things are taking a while,
        we send a newline along to maybe provoke a new prompt.  We wait for
        half the timeout period and then wait for one tenth of the timeout
        6 times (so we wait for 1.1 times the timeout period overall).
        :return: the index into the connection.prompt_str list
        """
        logger = logging.getLogger('dispatcher')
        prompt_wait_count = 0
        if not remaining:
            return self.wait()
        # connection_prompt_limit
        partial_timeout = remaining / 2.0
        while True:
            try:
                return self.raw_connection.expect(self.prompt_str, timeout=partial_timeout)
            except (pexpect.TIMEOUT, TestError) as exc:
                if prompt_wait_count < 6:
                    logger.warning(
                        '%s: Sending %s in case of corruption. Connection timeout %s, retry in %s',
                        exc, self.check_char, seconds_to_str(remaining), seconds_to_str(partial_timeout))
                    logger.debug("pattern: %s", self.prompt_str)
                    prompt_wait_count += 1
                    partial_timeout = remaining / 10
                    self.sendline(self.check_char)
                    continue
                else:
                    # TODO: is someone expecting pexpect.TIMEOUT?
                    print "error: upexpect timeout"
                    exit(-1)
            except KeyboardInterrupt:
                print "error : keyboard interrupt"
                exit(-1)

    def wait(self, max_end_time=None):
        """
        Simple wait without sendling blank lines as that causes the menu
        to advance without data which can cause blank entries and can cause
        the menu to exit to an unrecognised prompt.
        """
        if not max_end_time:
            timeout = self.timeout.duration
        else:
            timeout = max_end_time - time.time()
        if timeout < 0:
            print("Invalid max_end_time value passed to wait()")
            exit(-1)
        try:
            print("waiting: " + str(self.prompt_str) + " ,timeout:" + timeout)
            return self.raw_connection.expect(self.prompt_str, timeout=timeout)
        except (pexpect.TIMEOUT):
            print "error: time out"
            exit(-1)
        except KeyboardInterrupt:
            print "error: keyboard interrupt"
            exit(-1)

    def listen_feedback(self, timeout):
        """
        Listen to output and log as feedback
        """
        if timeout < 0:
            print("Invalid timeout value passed to listen_feedback()")
            exit(-1)
        try:
            self.raw_connection.logfile.is_feedback = True
            return self.raw_connection.expect([pexpect.EOF, pexpect.TIMEOUT],
                                              timeout=timeout)
        except KeyboardInterrupt:
            print "error: keyboard interrupt"
            exit(-1)
        finally:
            self.raw_connection.logfile.is_feedback = False

class SShSession(ShellSession):
    """ Extends a ShellSession to include the ability to copy files using scp
    without duplicating the SSH setup, keys etc.
    """
    def __init__(self, shell_command):
        super(SShSession, self).__init__(shell_command)
        self.name = "SshSession"

    def finalise(self):
        self.disconnect("closing")
        super(SShSession, self).finalise()

    def disconnect(self, reason):
        self.sendline('logout', disconnecting=True)
        self.connected = False


class IpmiSession(ShellSession):
    def __init__(self, shell_command):
        super(IpmiSession, self).__init__(shell_command)
        self.name = "IpmiSession"

    def finalise(self):
        self.disconnect("closing")
        super(IpmiSession, self).finalise()

    def disconnect(self, reason):
        self.sendline('~.', disconnecting=True)
        self.connected = False


class Timeout(object):
    """
    The Timeout class is a declarative base which any actions can use. If an Action has
    a timeout, that timeout name and the duration will be output as part of the action
    description and the timeout is then exposed as a modifiable value via the device_type,
    device or even job inputs. (Some timeouts may be deemed "protected" which may not be
    altered by the job. All timeouts are subject to a hardcoded maximum duration which
    cannot be exceeded by device_type, device or job input, only by the Action initialising
    the timeout.
    If a connection is set, this timeout is used per pexpect operation on that connection.
    If a connection is not set, this timeout applies for the entire run function of the action.
    """
    def __init__(self, name, duration=ACTION_TIMEOUT, protected=False):
        self.name = name
        self.start = 0
        self.elapsed_time = -1
        self.duration = duration  # Actions can set timeouts higher than the clamp.
        self.protected = protected

    @classmethod
    def default_duration(cls):
        return ACTION_TIMEOUT

    @classmethod
    def parse(cls, data):
        """
        Parsed timeouts can be set in device configuration or device_type configuration
        and can therefore exceed the clamp.
        """
        if not isinstance(data, dict):
            print("Invalid timeout data")
            exit(-1)
        duration = datetime.timedelta(days=data.get('days', 0),
                                      hours=data.get('hours', 0),
                                      minutes=data.get('minutes', 0),
                                      seconds=data.get('seconds', 0))
        if not duration:
            return Timeout.default_duration()
        return int(duration.total_seconds())

    def _timed_out(self, signum, frame):  # pylint: disable=unused-argument
        duration = int(time.time() - self.start)
        print("%s timed out after %s seconds" % (self.name, duration))
        exit(-1)

    @contextlib.contextmanager
    def __call__(self, action_max_end_time=None):
        self.start = time.time()
        if action_max_end_time is None:
            # action_max_end_time is None when cleaning the pipeline after a
            # timeout.
            # In this case, the job timeout is not taken into account.
            max_end_time = self.start + self.duration
        else:
            max_end_time = min(action_max_end_time, self.start + self.duration)

        duration = int(max_end_time - self.start)
        if duration <= 0:
            # If duration is lower than 0, then the timeout should be raised now.
            # Calling signal.alarm in this case will only deactivate the alarm
            # (by passing 0 or the unsigned value).
            self._timed_out(None, None)

        signal.signal(signal.SIGALRM, self._timed_out)
        signal.alarm(duration)

        try:
            yield max_end_time
        except:
            exit(-1)
        finally:
            # clear the timeout alarm, the action has returned
            signal.alarm(0)
            self.elapsed_time = time.time() - self.start

    def modify(self, duration):
        """
        Called from the parser if the job YAML wants to set an override on a per-action
        timeout. Complete job timeouts can be larger than the clamp.
        """
        if self.protected:
            raise JobError("Trying to modify a protected timeout: %s.", self.name)
        self.duration = max(min(OVERRIDE_CLAMP_DURATION, duration), 1)  # FIXME: needs support in /etc/

def stdout_logger():
    root = logging.getLogger()
    root.setLevel(logging.DEBUG)
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    root.addHandler(ch)
    return root

def run_command(command_list, allow_silent=False, allow_fail=False):  # pylint: disable=too-many-branches
    """
    Single location for all external command operations on the
    dispatcher, without using a shell and with full structured logging.
    Ensure that output for the YAML logger is a serialisable object
    and strip embedded newlines / whitespace where practical.
    Returns the output of the command (after logging the output)
    Includes default support for proxy settings in the environment.
    Blocks until the command returns then processes & logs the output.
     Caution: take care with the return value as this is highly dependent
    on the command_list and the expected results.
     :param: command_list - the command to run, with arguments
    :param: allow_silent - if True, the command may exit zero with no output
    without being considered to have failed.
    :return: On success (command exited zero), returns the command output.
    If allow_silent is True and the command produced no output, returns True.
    On failure (command exited non-zero), sets self.errors.
    If allow_silent is True, returns False, else returns the command output.
    """
    # FIXME: add option to only check stdout or stderr for failure output
    if not isinstance(command_list, list):
        print("commands to run_command need to be a list")
        exit(-1)
    log = None
    # nice is assumed to always exist (coreutils)
    command_list = ['nice'] + [str(s) for s in command_list]
    print("%s", ' '.join(command_list))
    try:
        log = subprocess.check_output(command_list, stderr=subprocess.STDOUT)
        log = log.decode('utf-8')  # pylint: disable=redefined-variable-type
    except subprocess.CalledProcessError as exc:
        # the errors property doesn't support removing errors
        errors = []
        if sys.version > '3':
            if exc.output:
                errors.append(exc.output.strip().decode('utf-8'))
            else:
                errors.append(str(exc))
            msg = '[%s] command %s\nmessage %s\noutput %s\n' % (
                ['RunCommand'], [i.strip() for i in exc.cmd], str(exc), str(exc).split('\n'))
        else:
            if exc.output:
                errors.append(exc.output.strip())
            elif exc.message:
                errors.append(exc.message)
            else:
                errors.append(str(exc))
            msg = "[%s] command %s\nmessage %s\noutput %s\nexit code %s" % (
                'RunCommand', [i.strip() for i in exc.cmd], [i.strip() for i in exc.message],
                exc.output.split('\n'), exc.returncode)
         # the exception is raised due to a non-zero exc.returncode
        if allow_fail:
            print(msg)
            log = exc.output.strip()
        else:
            for error in errors:
                errors = error
            print(msg)
            # if not allow_fail, fail the command
            return False
     # allow for commands which return no output
    if not log and allow_silent:
        return errors == []
    else:
        print('command output %s', log)
        return log

def ipmi_connection(connection_command, total_time):
    timeout = Timeout("ipmi-connection", total_time)

    logger = stdout_logger()
    # TODO : create IPMI connection
    command_str = connection_command

    print "the shell command is  : %s " % command_str
    shell = ShellCommand("%s\n" % command_str, timeout, logger=logger)
    if shell.exitstatus:
        print("%s command exited %d: %s" % (
            command_str, shell.exitstatus, shell.readlines()))
        exit(-1)

    # wait for login
    time.sleep(3)

    print "ipmi_connection : established"
    connection = IpmiSession(shell)

    connection.connected = True
    print "ipmi_connection : waiting"

    #default_shell_prompt = "SOL Session operational."
    #connection.prompt_str = [default_shell_prompt]
    #connection.wait()

    return connection

def ssh_connection(ssh_user, host, total_time):
    identity_file = None
    timeout = Timeout("ssh-conection", total_time)

    command = ['ssh']
    ssh_port = ["-p", "22"]
    default_shell_prompt = "ci-ssh: # "

    # add arguments to ignore host key checking of the host device
    command.extend(['-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=no'])
    if identity_file:
        command.extend(['-i', identity_file])

    command.extend(ssh_port)

    command_str = " ".join(str(item) for item in command)
    command.append("%s@%s" % (ssh_user, host))
    command_str = " ".join(str(item) for item in command)

    logger = stdout_logger()
    print "command str : " + command_str
    shell = ShellCommand("%s\n" % command_str, timeout, logger=logger)
    if shell.exitstatus:
        print("%s command exited %d: %s" % (
            command_str, shell.exitstatus, shell.readlines()))
        exit(-1)

    # wait for login
    time.sleep(3)
    # SshSession monitors the pexpect
    connection = SShSession(shell)
    connection.sendline('export PS1="%s"' % default_shell_prompt)
    connection.prompt_str = [default_shell_prompt]
    connection.connected = True
    connection.wait()
    return connection

if __name__ == '__main__':
    # test connection
    ssh_user = 'allplay'
    host = '192.168.67.60'
    time = 100
    connection = ssh_connection(ssh_user, host, time)
    connection.sendline("touch hello-world.txt")
    connection.wait()
    connection.disconnect("close")

    # test run command
    run_command(['ls'])
