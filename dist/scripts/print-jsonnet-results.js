#!/usr/bin/env node
"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
// @ts-check
const node_fs_1 = __importDefault(require("node:fs"));
const node_path_1 = __importDefault(require("node:path"));
const inputs = process.argv.slice(2);
const files = inputs.length ? inputs : [node_path_1.default.join('tests', 'results.json')];
function pad(str, len) {
    const s = String(str);
    if (s.length >= len)
        return s;
    return s + ' '.repeat(len - s.length);
}
// Simple color helpers (no deps)
const tty = process.stdout.isTTY && process.env.NO_COLOR !== '1';
const esc = (n) => `\u001b[${n}m`;
const color = (code, s) => (tty ? esc(code) + s + esc(0) : s);
const bold = (s) => color(1, s);
const red = (s) => color(31, s);
const green = (s) => color(32, s);
const gray = (s) => color(90, s);
const symbols = { pass: '✔', fail: '✖' };
function summarizeFailure(t) {
    try {
        // Prefer error message if present
        const got = t.got;
        if (got && typeof got === 'object' && 'err' in got && got.err) {
            return String(got.err);
        }
        // Fallback: show got vs want succinctly
        const gotStr = typeof t.got === 'string' ? t.got : JSON.stringify(t.got);
        const wantStr = typeof t.want === 'string' ? t.want : JSON.stringify(t.want);
        if (gotStr && wantStr && gotStr.length + wantStr.length < 120) {
            return `got=${gotStr} want=${wantStr}`;
        }
        return `got=${String(gotStr).slice(0, 80)}...`;
    }
    catch {
        return 'failure';
    }
}
let currentFile = null;
try {
    // Load and merge cases from one or more files
    const cases = [];
    for (const file of files) {
        currentFile = file;
        const raw = node_fs_1.default.readFileSync(file, 'utf8');
        const j = JSON.parse(raw);
        const arr = Array.isArray(j.cases) ? j.cases : [];
        cases.push(...arr);
    }
    // Pair Python rows after their corresponding Jsonnet row
    const norm = (n) => {
        let s = String(n || '');
        if (s.startsWith('python: '))
            s = s.slice(8);
        if (s.endsWith(' (python)'))
            s = s.slice(0, -9);
        return s;
    };
    const groups = new Map();
    let index = 0;
    for (const t of cases) {
        const base = norm(t.name);
        const isPy = t.name.endsWith(' (python)') || t.name.startsWith('python: ');
        if (!groups.has(base))
            groups.set(base, { primary: [], python: [], firstSeen: index });
        const g = groups.get(base);
        (isPy ? g.python : g.primary).push(t);
        index++;
    }
    const primaryOrder = [];
    for (const [base, g] of groups.entries()) {
        if (g.primary.length > 0)
            primaryOrder.push(base);
    }
    // Preserve discovery order by firstSeen
    primaryOrder.sort((a, b) => groups.get(a).firstSeen - groups.get(b).firstSeen);
    const pyOnlyOrder = [];
    for (const [base, g] of groups.entries()) {
        if (g.primary.length === 0)
            pyOnlyOrder.push(base);
    }
    pyOnlyOrder.sort((a, b) => groups.get(a).firstSeen - groups.get(b).firstSeen);
    const ordered = [];
    for (const base of primaryOrder) {
        const g = groups.get(base);
        ordered.push(...g.primary, ...g.python);
    }
    for (const base of pyOnlyOrder) {
        const g = groups.get(base);
        ordered.push(...g.python);
    }
    // Flat table
    const nameHeader = 'Test';
    const resultHeader = 'Result';
    const detailsHeader = 'Details';
    const sep = ' | ';
    let nameW = nameHeader.length;
    let resultW = resultHeader.length;
    for (const t of ordered) {
        nameW = Math.max(nameW, String(t.name || '').length);
        resultW = Math.max(resultW, t.pass ? 4 : 5);
    }
    console.log(bold(pad(nameHeader, nameW) + sep + pad(resultHeader, resultW) + sep + detailsHeader));
    console.log(gray('-'.repeat(nameW) + '-+-' + '-'.repeat(resultW) + '-+-' + '-'.repeat(detailsHeader.length)));
    for (const t of ordered) {
        const resTxt = t.pass ? 'Pass' : 'Fail';
        const resIcon = t.pass ? green(symbols.pass) : red(symbols.fail);
        const resCell = (t.pass ? green : red)(`${resIcon} ${resTxt}`);
        const details = t.pass ? '' : red(summarizeFailure(t));
        console.log(pad(t.name || '', nameW) + sep + pad(resCell, resultW + (tty ? 2 : 0)) + sep + details);
    }
    // Summary
    const total = ordered.length;
    const passed = ordered.filter(c => c.pass).length;
    const failed = total - passed;
    const summary = `Total: ${bold(String(total))}  Passed: ${green(String(passed))}  Failed: ${failed === 0 ? green('0') : red(String(failed))}`;
    console.log(summary);
    process.exit(failed === 0 ? 0 : 1);
}
catch (err) {
    console.error(`Failed to read or parse results file: ${currentFile ?? '(unknown)'}`);
    console.error(String(err));
    process.exit(2);
}
