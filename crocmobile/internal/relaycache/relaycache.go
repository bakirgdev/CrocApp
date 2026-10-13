// Package relaycache holds the public relay index picked for generated codes,
// in memory for the process (the v11 CLI keeps it in a file). It is internal so
// croctest can seed it without adding to the gobind API.
package relaycache

import "sync"

var best struct {
	sync.Mutex
	index int
	ok    bool
}

// Get returns the cached index, or calls pick and caches its result. A failed
// pick is not cached.
func Get(pick func() (int, error)) (int, error) {
	best.Lock()
	defer best.Unlock()
	if best.ok {
		return best.index, nil
	}
	index, err := pick()
	if err != nil {
		return 0, err
	}
	best.index, best.ok = index, true
	return index, nil
}

// Set caches index as if pick had returned it.
func Set(index int) {
	best.Lock()
	best.index, best.ok = index, true
	best.Unlock()
}

// Forget clears the cache, so the next Get picks again.
func Forget() {
	best.Lock()
	best.ok = false
	best.Unlock()
}
