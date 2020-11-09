#ifndef __Banyan_State_Item_h
#define __Banyan_State_Item_h

namespace Banyan {

  struct StateObject {
    enum Type {
      Null, Bool, Int, Double, String
    };

    Type type;

    StateObject()              { type = Null; }
    StateObject(int x)         { type = Int;    value__int    = x; }
    StateObject(double x)      { type = Double; value__double = x; }
    StateObject(std::string s) { type = String; value__string = s; }

    bool        value__bool;
    int         value__int;
    double      value__double;
    std::string value__string;
  };

}

#endif

