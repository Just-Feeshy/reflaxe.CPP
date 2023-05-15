#pragma once

#include "Dynamic.h"
namespace haxe {

class Dynamic_cxx_io_NativeOutput {
public:
	static Dynamic getProp(Dynamic& d, std::string name) {
		if(name == "stream") {
			return Dynamic::unwrap<cxx::io::NativeOutput>(d, [](cxx::io::NativeOutput* o) {
				return makeDynamic(o->stream);
			});
		} else 		if(name == "writeByte") {
			return Dynamic::makeFunc<cxx::io::NativeOutput>(d, [](cxx::io::NativeOutput* o, std::deque<Dynamic> args) {
				o->writeByte(args[0].asType<int>());
				return Dynamic();
			});
		} else 		if(name == "close") {
			return Dynamic::makeFunc<cxx::io::NativeOutput>(d, [](cxx::io::NativeOutput* o, std::deque<Dynamic> args) {
				o->close();
				return Dynamic();
			});
		} else 		if(name == "flush") {
			return Dynamic::makeFunc<cxx::io::NativeOutput>(d, [](cxx::io::NativeOutput* o, std::deque<Dynamic> args) {
				o->flush();
				return Dynamic();
			});
		} else 		if(name == "prepare") {
			return Dynamic::makeFunc<cxx::io::NativeOutput>(d, [](cxx::io::NativeOutput* o, std::deque<Dynamic> args) {
				o->prepare(args[0].asType<int>());
				return Dynamic();
			});
		}
		throw "Property does not exist";
	}

	static Dynamic setProp(Dynamic& d, std::string name, Dynamic value) {
		if(name == "stream") {
			return Dynamic::unwrap<cxx::io::NativeOutput>(d, [value](cxx::io::NativeOutput* o) {
				o->stream = value.asType<std::optional<std::ostream*>>();
				return value;
			});
		}
		throw "Property does not exist";
	}
};

}