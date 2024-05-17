package cxx.std;

import chrono.Duration;


// TODO: Possibly fully support for boost itself

@:cxxStd
@:cppStd
@:native("std::thread")
@:include("thread", true)
@:valueType
extern class Thread {
    @:nativeFunctionCode("new std::thread({func})")
    public function overload extern new(func:Void->Void);

	@:nativeFunctionCode("new std::thread({func}, {args})")
    @:overload(function(func:Void->Void):Void {})
	public function overload extern new(func:Void->Void, args:Dynamic);


	@:const @:noExcept public function joinable():Bool;
    public function join():Void;
    public function detach():Void;
	@:noExcept public function swap(other:cxx.Ref<Thread>):Void;

	@:nativeName("get_id") @:const @:noExcept public function getID():Int;

	@:native("std::thread::hardware_concurrency")
    public static overload extern function hardwareConcurrency():Int;

	@:native("std::this_thread::get_id")
    public static overload extern function getID():Int;
}
