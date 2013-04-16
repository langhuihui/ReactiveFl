package reactivefl.core
{
	import reactivefl.i.IDisposable;

	public class AbstractObserver extends Observer implements IDisposable
	{
		public var isStopped:Boolean;
		public function AbstractObserver()
		{
			super();
		}
		override public function onNext(value:*):void{
			if(!isStopped)next(value);
		}
		
		protected function next(value:*):void
		{
			// TODO Auto Generated method stub
			
		}
		override public function onError(e:Error):void{
			if(!isStopped){
				isStopped = true;
				error(e);
			}
		}
		override public function onCompleted():void{
			if(!isStopped){
				isStopped = true;
				completed();
			}
		}
		
		protected function completed():void
		{
			// TODO Auto Generated method stub
			
		}
		public function dispose():void{
			isStopped = true;
		}
		public function fail(e:Error):Boolean{
			if (!isStopped) {
				isStopped = true;
				error(e);
				return true;
			}
			return false;
		}
		
		protected function error(error:Error):void
		{
			
		}
	}
}