package reactivefl
{
	import reactivefl.core.AnonymousObservable;
	import reactivefl.core.Observable;
	import reactivefl.disposables.CompositeDisposable;
	import reactivefl.disposables.RefCountDisposable;
	import reactivefl.i.IDisposable;
	import reactivefl.i.IObserver;
	import reactivefl.subjects.Subject;

	public class RFL
	{
		public function RFL()
		{
		}
		public static function noop():void{}
		public static function defaultError(err:Error):void { throw err; }
		public static const sequenceContainsNoElements:String = "Sequence contains no elements.";
		public static const argumentOutOfRange:String = "argument out of range.";
		public static const objectDisposed:String = "Object is disposed";
		public static function defaultNow():Number{
			return new Date().getTime();
		}
		public static function identity(x:*):* { return x; }
		public static function defaultSubComparer(x:int, y:int):int { return x - y; }
		public static function defaultComparer(x:*, y:*):Boolean { return x === y; }
		public static function defaultKeySerializer(x:*):String { return x.toString(); }
		public static function checkDisposed(isDisposed:Boolean):void {
			if (isDisposed) {
				throw new Error(objectDisposed);
			}
		}
		public static function addRef(xs:Subject, r:RefCountDisposable):Observable {
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				return new CompositeDisposable(r.getDisposable(), xs.subscribe(observer));
			});
		};
		public static function arrayInitialize(count:uint, factory:Function):Array {
			var a:Array = new Array(count);
			for (var i:int = 0; i < count; i++) {
				a[i] = factory();
			}
			return a;
		}
	}
}