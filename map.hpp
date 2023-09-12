#include <string>
#include <vector>

template <class T>
struct Map {
  struct Entry {
    std::string name;
    T           item;
  };

  std::vector<Entry> entries;

  Map() {}
  Map(std::initializer_list<Entry> e) : entries(e) {}

  T& operator[](std::string name) {
    for (auto& entry : entries) {
      if (entry.name == name) {
        return entry.item;
      }
    }

    entries.push_back({name});
    return entries.back().item;
  }
};
