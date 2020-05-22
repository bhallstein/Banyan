#include "Banyan_NodeExportFn.h"

Banyan::NodeDef::Wrapper* _banyan_getDefinitions(int *n_defs) {
	auto &defs = Banyan::NodeDef::definitions();
	*n_defs = (int) defs.size();
	return (*n_defs > 0 ? &defs[0] : NULL);
}

bool _banyan_getExcThrown() {
	return Banyan::NodeDef::exc_thrown(false, false);
}
