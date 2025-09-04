#!/usr/bin/env python3
import json
import subprocess
import sys
import re

def load_blocks():
    try:
        p = subprocess.run(
            ["jsonnet", "test/regex_test.jsonnet"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except Exception as e:
        return None, f"failed to run jsonnet: {e}"
    try:
        data = json.loads(p.stdout)
        return data.get("blocks", {}), None
    except Exception as e:
        return None, f"failed to parse json: {e}"

def verify_with_python(blocks):
    cases = []
    flags = re.S  # dot matches newline to mirror custom engine

    # Validate: whether Python considers pattern valid (compilable)
    for v in blocks.get("validate", []):
        name = f"{v.get('name','')} (python)"
        pattern = v.get("pattern", "")
        expected_valid = v.get("py_expect")
        try:
            re.compile(pattern, flags)
            ok = True
        except re.error as err:
            ok = False
            err_msg = str(err)
        passed = (ok == (expected_valid if expected_valid is not None else ok))
        case = {
            "name": name,
            "pass": passed,
            "got": ok if ok else {"err": err_msg},
            "want": bool(expected_valid) if expected_valid is not None else ok,
        }
        cases.append(case)

    # Only verify match semantics; validation rules differ from Python's
    for m in blocks.get("match", []):
        name = f"{m.get('name','')} (python)"
        pattern = m.get("pattern", "")
        subject = m.get("subject", "")
        expect = bool(m.get("expect", False))
        try:
            ok = re.search(pattern, subject, flags) is not None
            passed = (ok == expect)
            cases.append({
                "name": name,
                "pass": passed,
                "got": ok,
                "want": expect,
            })
        except re.error as err:
            # If Python rejects the pattern, we treat it as a failure of equivalence
            cases.append({
                "name": name,
                "pass": False,
                "got": {"err": str(err)},
                "want": expect,
            })

    total = len(cases)
    failed = sum(1 for c in cases if not c.get("pass"))
    passed = total - failed
    return {
        "cases": cases,
        "total": total,
        "passed": passed,
        "failed": failed,
    }

def main():
    blocks, err = load_blocks()
    if err:
        out = {
            "cases": [{
                "name": "load blocks (python)",
                "pass": False,
                "got": {"err": err},
                "want": True,
            }],
            "total": 1,
            "passed": 0,
            "failed": 1,
        }
    else:
        out = verify_with_python(blocks)
    json.dump(out, sys.stdout)

if __name__ == "__main__":
    main()
