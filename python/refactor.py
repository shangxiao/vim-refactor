import rope.base.project
import vim
from rope.base import pynames, pyobjects
from rope.refactor.extract import ExtractMethod, ExtractVariable
from rope.refactor.inline import (
    InlineMethod,
    InlineParameter,
    InlineVariable,
    _get_pyname,
)


class Resource:
    path = "foo.py"
    real_path = path
    name = path  # used for debugging __repr__
    parent = None

    def __init__(self, name, code):
        self.name = self.path = self.real_path = name
        self.code = code

    def read(self):
        return self.code

    def read_bytes(self):
        return self.code

    def is_folder(self):
        return False

    def exists(self):
        return False


class MyInlineVariable(InlineVariable):
    def _init_imports(self):
        ...


class MyInlineMethod(InlineMethod):
    def _init_imports(self):
        ...


class MyInlineParameter(InlineParameter):
    def _init_imports(self):
        ...


def create_inline(project, resource, offset):
    pyname = _get_pyname(project, resource, offset)
    message = (
        "Inline refactoring should be performed on "
        "a method, local variable or parameter."
    )
    if pyname is None:
        raise rope.base.exceptions.RefactoringError(message)
    if isinstance(pyname, pynames.ImportedName):
        pyname = pyname._get_imported_pyname()
    if isinstance(pyname, pynames.AssignedName):
        return MyInlineVariable(project, resource, offset)
    if isinstance(pyname, pynames.ParameterName):
        return MyInlineParameter(project, resource, offset)
    if isinstance(pyname.get_object(), pyobjects.PyFunction):
        return MyInlineMethod(project, resource, offset)
    else:
        raise rope.base.exceptions.RefactoringError(message)


def extract_variable():
    base_directory = vim.eval("cwd")
    start = int(vim.eval("start"))
    end = int(vim.eval("end"))

    myproject = rope.base.project.Project(base_directory)
    resource = Resource(vim.current.buffer.name, "\n".join(vim.current.buffer[:]))
    extractor = ExtractVariable(myproject, resource, start, end)
    changes = extractor.get_changes("zzz", similar=True)
    vim.current.buffer[:] = changes.changes[0].new_contents.split("\n")


def extract_function():
    base_directory = vim.eval("cwd")
    start = int(vim.eval("start"))
    end = int(vim.eval("end"))

    myproject = rope.base.project.Project(base_directory)
    resource = Resource(vim.current.buffer.name, "\n".join(vim.current.buffer[:]))
    extractor = ExtractMethod(myproject, resource, start, end)
    extractor.kind = "function"
    changes = extractor.get_changes("zzz", similar=True)
    vim.current.buffer[:] = changes.changes[0].new_contents.split("\n")


def inline():
    base_directory = vim.eval("cwd")
    offset = int(vim.eval("offset"))

    myproject = rope.base.project.Project(base_directory)
    resource = Resource(vim.current.buffer.name, "\n".join(vim.current.buffer[:]))
    inliner = create_inline(myproject, resource, offset)
    changes = inliner.get_changes(resources=[resource])
    vim.current.buffer[:] = changes.changes[0].new_contents.split("\n")
