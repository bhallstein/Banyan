#include <vector>
#include <string>

template<class T>
struct Map {
  struct Entry {
    std::string name;
    T item;
  };

  std::vector<Entry> entries;

  Map() { }
  Map(std::initializer_list<Entry> e) : entries(e) { }

  T& operator[](std::string name) {
    for (auto it = entries.begin(); it < entries.end(); ++it) {
      if (it->name == name) {
        return it->item;
      }
    }

    entries.push_back({.name = name});
    return entries.back().item;
  }
};
