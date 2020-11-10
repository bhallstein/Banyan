#ifndef Helpers_h
#define Helpers_h

#import <Cocoa/Cocoa.h>
#include <string>
#include "Diatom.h"


// Defines
// -----------------------------------

#define DOC ((Document*) \
  [[NSDocumentController sharedDocumentController] currentDocument])

#define DOCW ((Document*) \
  [[[self window] windowController] document])

#define DISP [self setNeedsDisplay:YES]


// putUpError
// -----------------------------------

static void putUpError(NSString *title, NSString *detail) {
  NSError *err = [NSError errorWithDomain:@"" code:1257
                                 userInfo:@{ NSLocalizedDescriptionKey: title,
                                             NSLocalizedRecoverySuggestionErrorKey: detail }];
  [[NSAlert alertWithError:err] runModal];
}


// Node helpers
// -----------------------------------

typedef double UID;
extern Diatom EmptyDiatom;
const UID NotFound = -1;


struct UIDParentSearchResult {
  UID uid;
  std::string child_name;
};


static BOOL is_node_diatom(Diatom *n) {
  Diatom copy = *n;
  return copy.is_table() && copy["type"].is_string();
}


static BOOL node_has_position(Diatom *n) {
  return (*n)["posX"].is_number() && (*n)["posY"].is_number();
}


static Diatom& get_node(Diatom &tree, UID uid) {
  Diatom *result = NULL;

  tree.recurse([&](std::string name, Diatom &d) {
    if (is_node_diatom(&d) && d["uid"].is_number() && d["uid"].value__number == uid) {
      result = &d;
    }
  }, true);

  return result ? *result : EmptyDiatom;
}


static UIDParentSearchResult find_node_parent(Diatom &tree, UID uid) {
  UIDParentSearchResult result = { NotFound, "" };

  tree.recurse([&](std::string name, Diatom parent) {
    if (!is_node_diatom(&parent)) {
      return;
    }

    parent["children"].each([&](std::string name, Diatom child) {
      if (child["uid"].value__number == uid) {
        result = { parent["uid"].value__number, name };
      }
    });
  }, true);

  return result;
}


static UIDParentSearchResult find_node_parent(std::vector<Diatom> &tree, UID uid) {
  for (auto &t : tree) {
    UIDParentSearchResult result = find_node_parent(t, uid);
    if (result.uid != NotFound) {
      return result;
    }
  }

  return { NotFound, "" };
}


static BOOL is_ancestor(Diatom tree, UID uid__possible_ancestor, UID uid) {
  Diatom &d = get_node(tree, uid);
  Diatom &possible_ancestor = get_node(tree, uid__possible_ancestor);

  if (d.is_empty() || possible_ancestor.is_empty()) {
    return false;
  }

  bool result = false;
  possible_ancestor.recurse([&](std::string name, Diatom &n) {
    if (is_node_diatom(&n) && n["uid"].value__number == d["uid"].value__number) {
      result = true;
    }
  }, true);
  return result;
}


static BOOL is_ancestor(std::vector<Diatom> tree, UID uid__possible_ancestor, UID uid) {
  for (auto t : tree) {
    if (is_ancestor(t, uid__possible_ancestor, uid)) {
      return true;
    }
  }
  return false;
}


static std::vector<std::string> node_settable_properties(Diatom d) {
  std::vector<std::string> builtin_props = {
    "type",
    "maxChildren",
    "minChildren",
    "posX",
    "posY",
    "original_type",
    "description",
    "uid",
    "children",
  };

  std::vector<std::string> settables;
  d.each([&](std::string &prop_name, Diatom &d) {
    bool is_builtin_prop = std::find(builtin_props.begin(), builtin_props.end(), prop_name) != builtin_props.end();
    if (!is_builtin_prop) {
      settables.push_back(prop_name);
    }
  });
  return settables;
}


static int n_children(Diatom *node) {
  return (int) (*node)["children"].descendants.size();
}


// String helpers
// -----------------------------------

static NSString* nsstr(const std::string &s) {
  return [NSString stringWithFormat:@"%s", s.c_str()];
}

static NSString* nsstr(Diatom &d) {
  return nsstr(d.value__string);
}

static std::string numeric_key_string(std::string prefix, int n) {
  return prefix + std::to_string(n);
}

static int key_string_to_number(std::string k, std::string prefix) {
  return std::stoi(k.substr(prefix.length()));
}


#endif

