import assert from "node:assert/strict";

let suite = [];
let prefix = [];
let cleanup = [];

function partialMatch(actual, expected) {
  if (expected === null || typeof expected !== "object") return Object.is(actual, expected);
  if (actual === null || typeof actual !== "object") return false;
  return Object.entries(expected).every(([key, value]) => partialMatch(actual[key], value));
}

function matcher(actual, negated = false) {
  const check = (condition, message) => {
    if (negated ? condition : !condition) throw new assert.AssertionError({ message });
  };
  return {
    toBe(expected) {
      check(
        Object.is(actual, expected),
        `Expected ${String(actual)} to${negated ? " not" : ""} be ${String(expected)}`,
      );
    },
    toEqual(expected) {
      let equal = true;
      try {
        assert.deepStrictEqual(actual, expected);
      } catch {
        equal = false;
      }
      check(equal, `Values are${negated ? "" : " not"} deeply equal`);
    },
    toMatchObject(expected) {
      check(partialMatch(actual, expected), `Value does${negated ? "" : " not"} match object`);
    },
    toBeDefined() {
      check(actual !== undefined, `Value is${negated ? "" : " not"} defined`);
    },
    toBeUndefined() {
      check(actual === undefined, `Value is${negated ? "" : " not"} undefined`);
    },
    toContain(expected) {
      check(
        actual?.includes?.(expected) === true,
        `Value does${negated ? "" : " not"} contain ${String(expected)}`,
      );
    },
    toThrow() {
      let threw = false;
      try {
        actual();
      } catch {
        threw = true;
      }
      check(threw, `Function did${negated ? "" : " not"} throw`);
    },
    get not() {
      return matcher(actual, !negated);
    },
  };
}

export function expect(actual) {
  return matcher(actual);
}

export function describe(name, callback) {
  prefix.push(name);
  try {
    callback();
  } finally {
    prefix.pop();
  }
}

function register(name, callback) {
  suite.push({ name: [...prefix, name].join(" > "), callback });
}

register.each = (cases) => (name, callback) => {
  for (const values of cases) {
    const parameters = Array.isArray(values) ? values : [values];
    register(name, () => callback(...parameters));
  }
};

export const it = register;

export function afterEach(callback) {
  cleanup.push(callback);
}

export async function runRegisteredTests() {
  let failed = 0;
  for (const test of suite) {
    try {
      await test.callback();
      process.stdout.write(`✓ ${test.name}\n`);
    } catch (error) {
      failed += 1;
      process.stderr.write(
        `✗ ${test.name}\n  ${error instanceof Error ? error.stack : String(error)}\n`,
      );
    } finally {
      for (const callback of cleanup) await callback();
    }
  }
  const total = suite.length;
  suite = [];
  cleanup = [];
  return { total, failed };
}
