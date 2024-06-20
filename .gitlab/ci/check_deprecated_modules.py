import ast
import os
import sys
from http import HTTPStatus
from re import sub

import requests
import toml
from bs4 import BeautifulSoup

PROJECT_ROOT_DIR = os.path.abspath(f"{os.path.dirname(__file__)}/../..")


class HTTPError(Exception):
    pass


def is_module_deprecated_for_this_version(module_link, python_version):
    response = requests.get(module_link)
    if response.status_code != HTTPStatus.OK:
        raise HTTPError(
            f"Failed to fetch page content for url {module_link} : {response.status_code}"
        )

    soup = BeautifulSoup(response.content, "html.parser")
    deprecated_span = soup.find("span", class_="versionmodified deprecated")
    if deprecated_span is None:
        raise Exception(f"Failed to find deprecated span in {module_link}")

    parsed_version = sub(".*?(\d+\.\d+).*", r"\1", deprecated_span.text)
    our_version = list(map(int, python_version.split(".")))
    parsed_version = list(map(int, parsed_version.split(".")))

    return our_version[0] >= parsed_version[0] and our_version[1] >= parsed_version[1]


def fetch_deprecated_modules():
    version = get_python_version()
    url_base = f"https://docs.python.org/{version}/"
    module_list_url = url_base + "py-modindex.html"

    response = requests.get(module_list_url)
    if response.status_code != HTTPStatus.OK:
        raise Exception(f"Failed to fetch page content: {response.status_code}")

    soup = BeautifulSoup(response.content, "html.parser")
    rows = soup.select("tr")

    deprecated_modules = []
    for row in rows:
        cells = row.find_all("td")
        if len(cells) == 3:
            module_link = cells[1].find("a")
            module_status = cells[2].find("strong")
            if module_link and module_status and "Deprecated" in module_status.text:
                module_name = module_link.text
                module_link = module_link["href"]
                if is_module_deprecated_for_this_version(
                    url_base + module_link, version
                ):
                    deprecated_modules.append(module_name)

    return deprecated_modules


def get_python_version():
    with open(f"{PROJECT_ROOT_DIR}/pyproject.toml") as f:
        pyproject_data = toml.load(f)
        version_string = pyproject_data["project"].get("requires-python", "3.11")
        return sub(r"[><=^]*", "", version_string)


class DeprecatedModuleVisitor(ast.NodeVisitor):
    def __init__(self):
        self.deprecated_modules = fetch_deprecated_modules()
        self.deprecated_usages = []

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
        self.deprecated_usages.append(
            (
                module_name,
                lineno,
                relpath,
            )
        )


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
        dirs[:] = [d for d in dirs if d != "venv" and d != ".git"]
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
