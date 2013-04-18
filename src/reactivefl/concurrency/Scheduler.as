package reactivefl.concurrency
{
	import flash.utils.clearInterval;
	import flash.utils.setInterval;
	
	import reactivefl.RFL;
	import reactivefl.disposables.CompositeDisposable;
	import reactivefl.disposables.Disposable;
	import reactivefl.i.IDisposable;

	public class Scheduler
	{
		public static const schedulerNoBlockError:String = "Scheduler is not allowed to block the thread";
		public var now:Function;
		public static var now:Function = RFL.defaultNow;
		public function Scheduler(now:Function = null, schedule:Function = null, scheduleRelative:Function = null, scheduleAbsolute:Function = null)
		{
			this.now = now || RFL.defaultNow;
			this._schedule = schedule || scheduleNow;
			this._scheduleRelative = scheduleRelative || this.scheduleRelative;
			this._scheduleAbsolute = scheduleAbsolute || this.scheduleAbsolute;
		}
		protected function scheduleNow(state:*, action:Function):IDisposable {
			return null;
		}
		protected function scheduleRelative(state:*, dueTime:Number, action:Function):IDisposable{
			return null;
		}
		protected function scheduleAbsolute(state:*, dueTime:Number, action:Function):IDisposable{
			return null;
		}
		
		public static function  normalize  (timeSpan:Number):Number {
			return timeSpan<0?0:timeSpan;
		}
		public function schedule (action:Function):IDisposable {
			return this._schedule(action, invokeAction);
		};
		
		private var _schedule:Function;
		private var _scheduleRelative:Function;
		private var _scheduleAbsolute:Function;
		
		
		public function scheduleWithState(state:*, action:Function):IDisposable{
			return this._schedule(state, action);
		}
		public function scheduleRecursiveWithState (state:*, action:Function):IDisposable {
			return this.scheduleWithState(new Pair( state,  action ), invokeRecImmediate);
		};
		public function scheduleRecursive(action:Function):IDisposable
		{
			return this.scheduleRecursiveWithState(action, function (_action:Function, self:Function):void {
				_action(function ():void {
					self(_action);
				});
			});
		}
		
		public function scheduleWithAbsolute(dueTime:Number, action:Function):IDisposable
		{
			return _scheduleAbsolute(action, dueTime, invokeAction);
		}
		public function scheduleWithRelativeAndState(state:*, dueTime:Number, action:Function):IDisposable{
			return _scheduleRelative(state, dueTime, action);
		}
		public function scheduleWithAbsoluteAndState(state:*, dueTime:Number, action:Function):IDisposable {
			return this._scheduleAbsolute(state, dueTime, action);
		};
		public function scheduleRecursiveWithAbsolute(dueTime:Number, action:Function):IDisposable {
			return this.scheduleRecursiveWithAbsoluteAndState(action, dueTime, function (_action:Function, self:Function):void {
				_action(function (dt:Number):void {
					self(_action, dt);
				});
			});
		};
		public function scheduleRecursiveWithAbsoluteAndState(state:*, dueTime:Number, action:Function):IDisposable {
			return this._scheduleAbsolute({ first: state, second: action }, dueTime, function (s:Scheduler, p:Pair):CompositeDisposable {
				return invokeRecDate(s, p, scheduleWithAbsoluteAndState);
			});
		};
		private function invokeAction(scheduler:Scheduler, action:Function):IDisposable {
			action();
			return Disposable.empty;
		}
		private function invokeRecDate(scheduler:Scheduler, pair:Pair, method:Function):CompositeDisposable {
			var state:* = pair.first, action:Function = pair.second, group:CompositeDisposable = new CompositeDisposable(),
				recursiveAction:Function = function (state1:*):void {
					action(state1, function (state2:*, dueTime1:Number) :void{
						var isAdded:Boolean = false, isDone:Boolean = false,
						d:IDisposable = method( state2, dueTime1, function (scheduler1:Scheduler, state3:*):IDisposable {
							if (isAdded) {
								group.remove(d);
							} else {
								isDone = true;
							}
							recursiveAction(state3);
							return Disposable.empty;
						});
						if (!isDone) {
							group.add(d);
							isAdded = true;
						}
					});
				};
			recursiveAction(state);
			return group;
		}
		private function invokeRecImmediate(scheduler:Scheduler, pair:Pair) :CompositeDisposable{
			var state:* = pair.first, action:Function = pair.second, group:CompositeDisposable = new CompositeDisposable(),
				recursiveAction:Function = function (state1:*) :void{
					action(state1, function (state2:*):void {
						var isAdded:Boolean = false, isDone:Boolean = false,
						d:IDisposable = scheduler.scheduleWithState(state2, function (scheduler1:Scheduler, state3:Function):IDisposable {
							if (isAdded) {
								group.remove(d);
							} else {
								isDone = true;
							}
							recursiveAction(state3);
							return Disposable.empty;
						});
						if (!isDone) {
							group.add(d);
							isAdded = true;
						}
					});
				};
			recursiveAction(state);
			return group;
		}
		
		public function schedulePeriodicWithState(state:*, period:Number, action:Function):IDisposable {
			var s:* = state, id:uint = setInterval(function ():void {
				s = action(s);
			}, period);
			return Disposable.create(function ():void {
				clearInterval(id);
			});
		}
		
		public function scheduleWithRelative(dueTime:Number, action:Object):IDisposable
		{
			return this._scheduleRelative(action, dueTime, invokeAction);
		}
	}
}
class Pair{
	public var first:*;
	public var second:Function;
	public function Pair(f:*,s:Function){
		first = f;
		second =s;
	}
}