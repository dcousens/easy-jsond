module structs.json;

import std.conv : to;
import std.array : array;
import std.algorithm : map;
import std.range : ElementType;
import std.traits;

import std.json : JSONValue, JSON_TYPE;
static import std.json;

private auto valueify (T)(in T value) pure {
	static if (
		isArray!T ||
		isBoolean!T ||
		isNumeric!T ||
		isNarrowString!T
	) {
		return JSONValue(value);
	} else static if (isSomeChar!T) {
		return JSONValue([value]);
	} else {
		JSONValue j;
		foreach (i, ref x; value.tupleof) {
			const name = __traits(identifier, value.tupleof[i]);
			j[name] = valueify(x);
		}
		return j;
	}
}

private auto devalueify (T)(in JSONValue j) {
	static if (isArray!T) {
		static if (isNarrowString!T) {
			assert(j.type is JSON_TYPE.STRING);
			return to!T(j.str);
		} else {
			assert(j.type is JSON_TYPE.ARRAY);
			return j.array.map!(x => devalueify!(ElementType!T)(x)).array;
		}

	} else static if (isBoolean!T) {
		assert(j.type is JSON_TYPE.FALSE || j.type is JSON_TYPE.TRUE);
		return j.type == JSON_TYPE.TRUE;

	} else static if (isIntegral!T) {
		static if (isSigned!T) {
			assert(j.type is JSON_TYPE.INTEGER);
			return to!T(j.integer);
		}

		if (j.type is JSON_TYPE.UINTEGER) return to!T(j.uinteger);
		assert(j.type is JSON_TYPE.INTEGER);
		return to!T(j.integer);

	} else static if (isFloatingPoint!T) {
		assert(
			j.type is JSON_TYPE.FLOAT ||
			j.type is JSON_TYPE.INTEGER ||
			j.type is JSON_TYPE.UINTEGER
		);
		return to!T(j.floating);

	} else static if (isSomeChar!T) {
		assert(j.type is JSON_TYPE.STRING);
		return to!T(j.str[0]);

	} else {
		assert(j.type is JSON_TYPE.OBJECT);

		T t;
		foreach (i, ref x; t.tupleof) {
			alias XT = typeof(x);
			const name = __traits(identifier, t.tupleof[i]);

			x = devalueify!(XT)(j[name]);
		}
		return t;
	}
}

auto stringify (T)(in T t) {
	const j = valueify!T(t);
	return std.json.toJSON(j);
}

auto parse (T)(in string s) {
	const j = std.json.parseJSON(s);
	return devalueify!T(j);
}

unittest {
	struct Bar {
		double a;
		float b;
		string c;
		char[] d;
	}

	struct Foo {
		int a;
		ushort b;
		char c;
		ushort[2] d;
		Bar child;
	}

	const expected = Foo(12345, 0x10, 'z', [7,8], Bar(99.001, 200.06335, "foo", ['a', 'b']));
	const str = stringify(expected);
	const actual = parse!Foo(str);

	assert(actual == expected);
}
