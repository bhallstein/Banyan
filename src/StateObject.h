#ifndef __Banyan_State_Item_h
#define __Banyan_State_Item_h

namespace Banyan {

  struct StateObject {
    enum Type {
      Null, Bool, Int, Double, String
    };

    Type type;

    StateObject()              { type = Null; }
    StateObject(int x)         { type = Int;    int_value    = x; }
    StateObject(double x)      { type = Double; double_value = x; }
    StateObject(std::string s) { type = String; string_value = s; }

    bool        bool_value;
    int         int_value;
    double      double_value;
    std::string string_value;
  };

}

#endif

