package reactivefl.core
{
	public class Notification
	{
		public var hasValue:Boolean;
		private var _accept:Function;
		private var _acceptObservable:Function;
		private var value:*;
		private var exception:Error;
		private var kind:String;
		private var toString:Function;
		public function Notification(kind:String,hasValue:Boolean = false)
		{
			this.hasValue = hasValue;
			this.kind = kind;
		}
		
		public function accept(observerOrOnNext:Object, onError:Function = null, onCompleted:Function = null):*
		{
			if(observerOrOnNext is Function && onError!=null && onCompleted!=null){
				return _accept(observerOrOnNext, onError, onCompleted);
			}
			return _acceptObservable(observerOrOnNext);
		}
		public static function createOnNext(value:*):Notification{
			var notification:Notification = new Notification('N', true);
			notification.value = value;
			notification._accept = function(onNext:Function):*{
				return onNext(value);
			};
			notification._acceptObservable = function(observer:Observer):*{
				return observer.onNext(value);
			}
			notification.toString = function():String{return 'OnNext(' + this.value + ')';};
			return notification;
		}
		public static function createOnError(exception:Error):Notification{
			var notification:Notification = new Notification('E', true);
			notification.exception = exception;
			notification._accept = function(onNext:Function,onError:Function):*{
				return onError(exception);
			};
			notification._acceptObservable = function(observer:Observer):*{
				return observer.onError(exception);
			}
			notification.toString = function():String{return 'OnError(' + this.value + ')';};
			return notification;
		}
		
		public static function createOnCompleted():Notification
		{
			var notification:Notification = new Notification('C', true);
			notification._accept = function(onNext:Function,onError:Function,onCompleted:Function):*{
				return onCompleted();
			};
			notification._acceptObservable = function(observer:Observer):*{
				return observer.onCompleted();
			}
			notification.toString = function():String{return 'OnCompleted()';};
			return notification;
		}
	}
}