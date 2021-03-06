import io

from okdata.cli.command import BaseCommand
from okdata.cli.output import TableOutput
from conftest import set_argv


def test_docopt():
    set_argv("datasets", "--debug", "--format", "yaml")

    cmd = BaseCommand()

    assert cmd.cmd("datasets") is True
    assert cmd.opt("debug") is True
    assert cmd.opt("format") == "yaml"
    assert cmd.cmd("notexisting") is None
    assert cmd.arg("notexisting") is None
    assert cmd.opt("notexisting") is None


def test_cmd_empty_handler():
    set_argv("datasets", "--debug", "--format", "yaml")
    cmd = BaseCommand()
    assert cmd.handle() is None


def test_cmd_with_handler():
    set_argv("datasets", "--debug", "--format", "yaml")
    cmd = BaseCommand()
    cmd.handler = lambda: True
    assert cmd.handle() is True


def test_cmd_with_sub_command():
    set_argv("datasets", "--debug", "--format", "yaml")
    cmd = BaseCommand()
    sub_cmd = BaseCommand
    cmd.sub_commands = [sub_cmd]
    cmd.handler = lambda: True
    assert cmd.handle() is None


def test_invalid_docopt_for_subcommand():
    class SubCommand(BaseCommand):
        """
        usage:
            illegal usage
        """

    set_argv("datasets", "--debug", "--format", "yaml")

    cmd = BaseCommand()
    cmd.sub_commands = [SubCommand]
    cmd.handler = lambda: True
    assert cmd.handle() is True


class FileCommand(BaseCommand):
    """
    usage:
        okdata datasets -
        okdata datasets --file=<file>
    """


def test_handle_input_from_file(mocker):
    mocker.patch("builtins.open", mocker.mock_open(read_data="open_file"))
    set_argv("datasets", "--file", "input.json")
    cmd = FileCommand()
    content = cmd.handle_input()
    assert content == "open_file"


def test_handle_input_from_stdin(monkeypatch):
    monkeypatch.setattr("sys.stdin", io.StringIO("stdin"))
    set_argv("datasets", "-")
    cmd = FileCommand()
    content = cmd.handle_input()
    assert content == "stdin"


def test_pretty_json(capsys):
    set_argv("datasets")
    cmd = BaseCommand()
    cmd.pretty_json({"Hello": {"foo": "bar"}})
    captured = capsys.readouterr()
    assert (
        captured.out
        == '{\n  \x1b[94m"Hello"\x1b[39;49;00m: {\n    \x1b[94m"foo"\x1b[39;49;00m: \x1b[33m"bar"\x1b[39;49;00m\n  }\n}\n\n'
    )


def test_pretty_print_success(capsys):
    set_argv("datasets")
    cmd = BaseCommand()
    config = {
        "name": {"name": "name", "key": "name"},
        "id": {"name": "key", "key": "key"},
    }
    cmd.print_success(TableOutput(config), [{"name": "hello", "key": "world"}])
    captured = capsys.readouterr()
    assert (
        captured.out
        == """+-------+-------+
| name  | key   |
+-------+-------+
| hello | world |
+-------+-------+
"""
    )


def test_help(capsys):
    set_argv("datasets")
    cmd = BaseCommand()
    cmd.help()
    captured = capsys.readouterr()
    assert captured.out == BaseCommand.__doc__
