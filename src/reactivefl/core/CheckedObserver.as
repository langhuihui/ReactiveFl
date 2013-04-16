package reactivefl.core
{
	
	public class CheckedObserver extends Observer
	{
		private var _state:int;
		private var _observer:Observer;
		public function CheckedObserver(observer:Observer)
		{
			super();
			_observer = observer;
		}
		override public function onNext(value:*):void{
			checkAccess();
			try {
				_observer.onNext(value);
			} catch (e:Error) { 
				throw e;                
			} finally {
				_state = 0;
			}
		};
		override public function onError(error:Error):void{
			checkAccess();
			try {
				_observer.onError(error);
			} catch (e:Error) { 
				throw e;                
			} finally {
				_state = 2;
			}
		}
		override public function onCompleted():void{
			checkAccess();
			try {
				_observer.onCompleted();
			} catch (e:Error) { 
				throw e;                
			} finally {
				_state = 2;
			}
		}
		private function checkAccess():void{
			if (_state === 1) { throw new Error('Re-entrancy detected'); }
			if (_state === 2) { throw new Error('Observer completed'); }
			if (_state === 0) { _state = 1; }
		}
	}
}