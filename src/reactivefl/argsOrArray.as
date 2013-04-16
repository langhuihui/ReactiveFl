package reactivefl
{
	public function argsOrArray(args:Array,index:int = 0):Array
	{
		return args.length === 1 && args[index] is Array?args[index] :args;
	}
}