package reactivefl.vo
{
	public class ValueWithTimestamp
	{
		public var value:*;
		public var timestamp:Number;
		public function ValueWithTimestamp(v:*,t:Number)
		{
			value = v;timestamp = t;
		}
	}
}