import ast
import os
import sys
from http import HTTPStatus
from re import search
from urllib.parse import urljoin

import requests
import toml
from bs4 import BeautifulSoup

PROJECT_ROOT_DIR = os.path.abspath(f"{os.path.dirname(__file__)}/../..")


class HTTPError(Exception):
    pass


def fetch_deprecated_modules():
    version = get_python_version()
    url_base = f"https://docs.python.org/{version}/"
    module_list_url = urljoin(url_base, "py-modindex.html")

    response = requests.get(module_list_url, timeout=15)
    if response.status_code != HTTPStatus.OK:
        raise HTTPError(f"Failed to fetch page content: {response.status_code}")

    soup = BeautifulSoup(response.content, "html.parser")

    deprecated_modules = []
    seen = set()

    for row in soup.select("tr"):
        row_text = " ".join(row.stripped_strings)
        if "Deprecated:" not in row_text:
            continue

        link = row.select_one("a[href]")
        if not link:
            continue

        module_name = link.get_text(strip=True)
        if module_name and module_name not in seen:
            seen.add(module_name)
            deprecated_modules.append(module_name)

    return deprecated_modules


def get_python_version():
    with open(f"{PROJECT_ROOT_DIR}/pyproject.toml") as f:
        pyproject_data = toml.load(f)
    version_string = pyproject_data["project"].get("requires-python", "3.13.5")
    match = search(r"(\d+\.\d+)", version_string)
    return match.group(1) if match else "3.13.5"


class DeprecatedModuleVisitor(ast.NodeVisitor):
    def __init__(self):
        self.deprecated_modules = fetch_deprecated_modules()
        self.deprecated_usages = []
        self.current_file = None

    def visit_Import(self, node):
        for alias in node.names:
            if alias.name in self.deprecated_modules:
                self.__append_deprecated_usage(alias.name, node.lineno)
        self.generic_visit(node)

    def visit_ImportFrom(self, node):
        if node.module in self.deprecated_modules:
            self.__append_deprecated_usage(node.module, node.lineno)
        self.generic_visit(node)

    def __append_deprecated_usage(self, module_name, lineno):
        relpath = "./" + os.path.relpath(self.current_file, PROJECT_ROOT_DIR)
        self.deprecated_usages.append((module_name, lineno, relpath))


def file_has_python_shebang(file_path):
    try:
        with open(file_path) as f:
            first_line = f.readline().strip()
            return first_line.startswith("#!") and "python" in first_line
    except (OSError, UnicodeDecodeError):
        return False


def scan_for_deprecated_modules():
    visitor = DeprecatedModuleVisitor()
    for root, dirs, files in os.walk(PROJECT_ROOT_DIR):
        dirs[:] = [d for d in dirs if d not in {"venv", ".venv", ".git"}]
        for file in files:
            file_path = os.path.join(root, file)
            if file.endswith(".py") or file_has_python_shebang(file_path):
                with open(file_path) as f:
                    try:
                        visitor.current_file = file_path
                        tree = ast.parse(f.read(), filename=file)
                        visitor.visit(tree)
                    except SyntaxError as e:
                        print(f"Syntax error in {file_path}: {e}")
    return visitor.deprecated_usages


if __name__ == "__main__":
    deprecated_usages = scan_for_deprecated_modules()
    if deprecated_usages:
        for module, lineno, file_path in deprecated_usages:
            print(
                f"Deprecated module '{module}' used in file '{file_path}' at line {lineno}."
            )
        sys.exit(1)
    else:
        print("No deprecated modules found.")
        sys.exit(0)
