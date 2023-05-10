// =======================================================
// * Dynamic
//
// This sub-compiler is used to handle compiling anything
// related to the Dynamic type.
//
// Dynamic requires simulating an entire system without
// using any types, so it's a big area of focus for
// a C++ target.
// =======================================================

package cxxcompiler.subcompilers;

#if (macro || cxx_runtime)

import reflaxe.data.ClassVarData;
import reflaxe.data.ClassFuncData;

using reflaxe.helpers.SyntaxHelper;
using reflaxe.helpers.TypeHelper;

@:allow(cxxcompiler.Compiler)
@:access(cxxcompiler.Compiler)
class Dynamic_ extends SubCompiler {
	public var enabled(default, null): Bool = false;

	public function enableDynamic() {
		enabled = true;
	}

	public function compileDynamicTypeName() {
		return "haxe::Dynamic";
	}

	var valueType: String = "";
	var dynamicName: String = "";
	var getProps: Array<String> = [];
	var setProps: Array<String> = [];

	public function reset(valueTypeCpp: String) {
		valueType = valueTypeCpp;
		dynamicName = "Dynamic_" + StringTools.replace(valueTypeCpp, "::", "_");
		getProps = [];
		setProps = [];
	}

	public function addVar(v: ClassVarData, cppType: String, name: String) {
		if(v.read == AccNormal || v.read == AccNo) {
			getProps.push('if(name == "${name}") {
	return Dynamic::unwrap<${valueType}>(d, [](${valueType}* o) {
		return makeDynamic(o->${name});
	});
}');
		}
		if(v.write == AccNormal || v.write == AccNo) {
			setProps.push('if(name == "${name}") {
	return Dynamic::unwrap<${valueType}>(d, [value](${valueType}* o) {
		o->${name} = value.asType<${cppType}>();
		return value;
	});
}');
		}
	}

	public function addFunc(v: ClassFuncData, cppArgs: Array<String>, name: String) {
		if(v.field.name == "new") return;
		final hasRet = !v.ret.isVoid();
		final args = [];
		for(i in 0...cppArgs.length) {
			args.push('args[${i}].asType<${cppArgs[i]}>()');
		}

		final content = if(hasRet) {
			'return makeDynamic(o->${name}(${args.join(", ")}));';
		} else {
			'o->${name}(${args.join(", ")});\n\t\treturn Dynamic();';
		}

		getProps.push('if(name == "${name}") {
	return Dynamic::makeFunc<${valueType}>(d, [](${valueType}* o, std::deque<Dynamic> args) {
		${content}
	});
}');
	}

	public function getDynamicContent() {
		return '
namespace haxe {

class ${dynamicName}: public Dynamic {
public:
	static Dynamic getProp(Dynamic& d, std::string name) {
${getProps.map(p -> p.tab(2)).join(" else ")}
		throw \"Property does not exist\";
	}

	static Dynamic setProp(Dynamic& d, std::string name, Dynamic value) {
${setProps.map(p -> p.tab(2)).join(" else ")}
		throw \"Property does not exist\";
	}
};

}';
	}

	/**
		Get dynamic.
	**/
	public function dynamicTypeContent() {
		return "#pragma once

#include <any>
#include <deque>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <typeindex>

namespace haxe {

// Forward declare just in case
template<typename T> class _class;

// The different types of Dynamic values
enum DynamicType {
	Empty, Null, Function, Value, Pointer, Reference, UniquePtr, SharedPtr
};

// ---

// A helper class for extracting certain info from types
template<typename T>
struct _mm_type { using inner = T; constexpr static DynamicType type = Value; };

template<typename T>
struct _mm_type<T*> { using inner = T; constexpr static DynamicType type = Pointer; };

template<typename T>
struct _mm_type<std::shared_ptr<T>> { using inner = T; constexpr static DynamicType type = SharedPtr; };

// Unwrap references as they're incompatible with `std::any`.
template<typename T>
struct _mm_type<T&> { using inner = typename _mm_type<T>::inner; constexpr static DynamicType type = _mm_type<T>::type; };

// Due to their nature, `unique_ptr` cannot be stored in `Dynamic`.
// But let's track anyway for error reporting.
template<typename T>
struct _mm_type<std::unique_ptr<T>> { using inner = T; constexpr static DynamicType type = UniquePtr; };

// ---

// The class used for Haxe's `Dynamic` type.
class Dynamic {
public:
	DynamicType _dynType;
	std::optional<std::type_index> _innerType;
	std::any _anyObj;
	std::function<Dynamic(std::deque<Dynamic>)> func;

	std::function<Dynamic(Dynamic&,std::string)> getFunc;
	std::function<Dynamic(Dynamic&,std::string,Dynamic)> setFunc;

	Dynamic() {
		_dynType = Empty;
	}

	template<typename T>
	Dynamic(T obj) {
		using inner = typename _mm_type<T>::inner;

		_anyObj = obj;
		_innerType = std::type_index(typeid(inner));
		_dynType = _mm_type<T>::type;

		// We cannot copy or move `std::unique_ptr`s
		if(_dynType == UniquePtr) {
			throw \"Cannot assign std::unique_ptr to haxe::Dynamic\";
		}

		// Supply properties if possible.
		// Otherwise, Dynamic works as a simple `std::any` wrapper.
		if constexpr(haxe::_class<inner>::data.has_dyn) {
			using Dyn = typename haxe::_class<inner>::Dyn;
			getFunc = [](Dynamic& d, std::string name) { return Dyn::getProp(d, name); };
			setFunc = [](Dynamic& d, std::string name, Dynamic value) { return Dyn::setProp(d, name, value); };
		}
	}

	static Dynamic null() {
		Dynamic result;
		result._dynType = Null;
		return result;
	}

	bool isNull() const {
		return _dynType == Null;
	}

	bool isEmpty() const {
		return _dynType == Empty;
	}

	bool isFunction() const {
		return _dynType == Function;
	}

	template<typename T>
	bool isType() const {
		if(isEmpty()) return false;
		if(!_innerType) return false;
		return _innerType.value() == std::type_index(typeid(T));
	}

	bool isInt() const {
		return isType<int>();
	}

	bool isFloat() const {
		return isType<double>();
	}

	bool isString() const {
		return isType<std::string>();
	}

	template<typename T>
	T asType() const {
		using In = typename _mm_type<T>::inner;
		if constexpr(_mm_type<T>::type == Value) {
			switch(_dynType) {
				case Value: return std::any_cast<T>(_anyObj);
				case Pointer: return *std::any_cast<T*>(_anyObj);

				// Cannot store references in `std::any`.
				// case Reference: return std::any_cast<T&>(_anyObj);

				// Cannot store `unique_ptr`.
				// case UniquePtr: return *std::any_cast<std::unique_ptr<T>>(_anyObj);

				case SharedPtr: return *std::any_cast<std::shared_ptr<T>>(_anyObj);
				default: break;
			}
		} else if constexpr(_mm_type<T>::type == Pointer) {
			switch(_dynType) {
				case Pointer: return std::any_cast<In*>(_anyObj);

				// Cannot store `unique_ptr`.
				// case 3: return std::any_cast<std::unique_ptr<In>>(_anyObj).get();

				case SharedPtr: return std::any_cast<std::shared_ptr<In>>(_anyObj).get();
				default: break;
			}
		} else if constexpr(_mm_type<T>::type == Reference) {
			throw \"Cannot cast Dynamic to reference (&)\";
		} else if constexpr(_mm_type<T>::type == UniquePtr) {
			throw \"Cannot cast Dynamic to std::unique_ptr\";
		} else if constexpr(_mm_type<T>::type == SharedPtr) {
			if(_dynType == SharedPtr) {
				return std::any_cast<std::shared_ptr<In>>(_anyObj);
			}
		}
		
		throw \"Bad Dynamic cast\";
	}

	std::string toString() {
		if(getFunc != nullptr) {
			Dynamic toString = getFunc(*this, \"toString\");
			if(toString.isFunction()) {
				Dynamic result = toString();
				if(result.isString()) {
					return result.asType<std::string>();
				}
			}
		}
		switch(_dynType) {
			case Empty: return std::string(\"Dynamic(Undefined)\");
			case Null: return std::string(\"Dynamic(null)\");
			case Function: return std::string(\"Dynamic(Function)\");
			default: break;
		}
		if(isInt()) {
			return std::to_string(asType<int>());
		} else if(isFloat()) {
			return std::to_string(asType<double>());
		}
		return std::string(\"Dynamic\");
	}

	virtual Dynamic getProp(std::string name) {
		if(getFunc != nullptr) {
			Dynamic result = getFunc(*this, name);
			if(!result.isEmpty()) return result;
		}
		throw \"Property does not exist\";
	}

	virtual Dynamic setProp(std::string name, Dynamic value) {
		if(setFunc != nullptr) {
			Dynamic result = setFunc(*this, name, value);
			if(!result.isEmpty()) return result;
		}
		throw \"Property does not exist\";
	}

	virtual Dynamic operator()() {
		if(_dynType == Function) {
			return func({});
		}
		throw \"Cannot call this Dynamic\";
	}

	virtual Dynamic operator()(std::deque<Dynamic> args) {
		if(_dynType == Function) {
			return func(args);
		}
		throw \"Cannot call this Dynamic\";
	}

	// helpers

	template<typename T>
	static Dynamic unwrap(Dynamic& d, std::function<Dynamic(T*)> callback) {
		std::optional<T> v;
		if(d._dynType == Value) v = std::any_cast<T>(d._anyObj);
		else v = std::nullopt;
		T* p = nullptr;
		if(d._dynType == Value) {
			p = v.operator->();
		} else {
			p = d.asType<T*>();
		}
		return callback(p);
	}

	template<typename T>
	static Dynamic makeFunc(Dynamic& d, std::function<Dynamic(T*, std::deque<Dynamic>)> callback) {
		Dynamic result;
		result._dynType = Function;
		result.func = [callback, d](std::deque<Dynamic> args) {
			std::optional<T> v;
			if(d._dynType == Value) v = std::any_cast<T>(d._anyObj);
			else v = std::nullopt;
			T* p = nullptr;
			if(d._dynType == Value) {
				p = v.operator->();
			} else {
				p = d.asType<T*>();
			}
			return callback(p, args);
		};
		return result;
	}
};

template<typename T>
Dynamic makeDynamic(T obj) {
	return Dynamic(obj);
}

}";
	}
}

#end
