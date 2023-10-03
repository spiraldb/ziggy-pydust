from __future__ import annotations

class Comparator:
    def __init__(num, /):
        pass
    def __lt__(self, value, /):
        """
        Return self<value.
        """
        ...
    def __le__(self, value, /):
        """
        Return self<=value.
        """
        ...
    def __eq__(self, value, /):
        """
        Return self==value.
        """
        ...
    def __ne__(self, value, /):
        """
        Return self!=value.
        """
        ...
    def __gt__(self, value, /):
        """
        Return self>value.
        """
        ...
    def __ge__(self, value, /):
        """
        Return self>=value.
        """
        ...
    __hash__: NoneType

class Equals:
    def __init__(num, /):
        pass
    def __lt__(self, value, /):
        """
        Return self<value.
        """
        ...
    def __le__(self, value, /):
        """
        Return self<=value.
        """
        ...
    def __eq__(self, value, /):
        """
        Return self==value.
        """
        ...
    def __ne__(self, value, /):
        """
        Return self!=value.
        """
        ...
    def __gt__(self, value, /):
        """
        Return self>value.
        """
        ...
    def __ge__(self, value, /):
        """
        Return self>=value.
        """
        ...
    __hash__: NoneType

class LessThan:
    def __init__(name, /):
        pass
    def __lt__(self, value, /):
        """
        Return self<value.
        """
        ...
    def __le__(self, value, /):
        """
        Return self<=value.
        """
        ...
    def __eq__(self, value, /):
        """
        Return self==value.
        """
        ...
    def __ne__(self, value, /):
        """
        Return self!=value.
        """
        ...
    def __gt__(self, value, /):
        """
        Return self>value.
        """
        ...
    def __ge__(self, value, /):
        """
        Return self>=value.
        """
        ...
    __hash__: NoneType

class Operator:
    def __init__(num, /):
        pass
    def __truediv__(self, value, /):
        """
        Return self/value.
        """
        ...
    def __rtruediv__(self, value, /):
        """
        Return value/self.
        """
        ...
    def num(self, /): ...

class Ops:
    def __init__(num, /):
        pass
    def __add__(self, value, /):
        """
        Return self+value.
        """
        ...
    def __radd__(self, value, /):
        """
        Return value+self.
        """
        ...
    def __sub__(self, value, /):
        """
        Return self-value.
        """
        ...
    def __rsub__(self, value, /):
        """
        Return value-self.
        """
        ...
    def __mul__(self, value, /):
        """
        Return self*value.
        """
        ...
    def __rmul__(self, value, /):
        """
        Return value*self.
        """
        ...
    def __mod__(self, value, /):
        """
        Return self%value.
        """
        ...
    def __rmod__(self, value, /):
        """
        Return value%self.
        """
        ...
    def __divmod__(self, value, /):
        """
        Return divmod(self, value).
        """
        ...
    def __rdivmod__(self, value, /):
        """
        Return divmod(value, self).
        """
        ...
    def __pow__(self, value, mod=None, /):
        """
        Return pow(self, value, mod).
        """
        ...
    def __rpow__(self, value, mod=None, /):
        """
        Return pow(value, self, mod).
        """
        ...
    def __lshift__(self, value, /):
        """
        Return self<<value.
        """
        ...
    def __rlshift__(self, value, /):
        """
        Return value<<self.
        """
        ...
    def __rshift__(self, value, /):
        """
        Return self>>value.
        """
        ...
    def __rrshift__(self, value, /):
        """
        Return value>>self.
        """
        ...
    def __and__(self, value, /):
        """
        Return self&value.
        """
        ...
    def __rand__(self, value, /):
        """
        Return value&self.
        """
        ...
    def __xor__(self, value, /):
        """
        Return self^value.
        """
        ...
    def __rxor__(self, value, /):
        """
        Return value^self.
        """
        ...
    def __or__(self, value, /):
        """
        Return self|value.
        """
        ...
    def __ror__(self, value, /):
        """
        Return value|self.
        """
        ...
    def __iadd__(self, value, /):
        """
        Return self+=value.
        """
        ...
    def __isub__(self, value, /):
        """
        Return self-=value.
        """
        ...
    def __imul__(self, value, /):
        """
        Return self*=value.
        """
        ...
    def __imod__(self, value, /):
        """
        Return self%=value.
        """
        ...
    def __ipow__(self, value, /):
        """
        Return self**=value.
        """
        ...
    def __ilshift__(self, value, /):
        """
        Return self<<=value.
        """
        ...
    def __irshift__(self, value, /):
        """
        Return self>>=value.
        """
        ...
    def __iand__(self, value, /):
        """
        Return self&=value.
        """
        ...
    def __ixor__(self, value, /):
        """
        Return self^=value.
        """
        ...
    def __ior__(self, value, /):
        """
        Return self|=value.
        """
        ...
    def __floordiv__(self, value, /):
        """
        Return self//value.
        """
        ...
    def __rfloordiv__(self, value, /):
        """
        Return value//self.
        """
        ...
    def __truediv__(self, value, /):
        """
        Return self/value.
        """
        ...
    def __rtruediv__(self, value, /):
        """
        Return value/self.
        """
        ...
    def __ifloordiv__(self, value, /):
        """
        Return self//=value.
        """
        ...
    def __itruediv__(self, value, /):
        """
        Return self/=value.
        """
        ...
    def __matmul__(self, value, /):
        """
        Return self@value.
        """
        ...
    def __rmatmul__(self, value, /):
        """
        Return value@self.
        """
        ...
    def __imatmul__(self, value, /):
        """
        Return self@=value.
        """
        ...
    def num(self, /): ...
