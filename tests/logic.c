#include <assert.h>
#include "../NGLogic.h"
int main(void) {
    assert(NGClamp(NAN,2,.5,6)==2);
    assert(NGClamp(999,2,.5,6)==6);
    assert(NGClamp(-1,2,.5,6)==.5);
    assert(NGShouldRender(1,1,1,0,1,0,1));
    assert(NGShouldRender(1,0,0,1,1,0,1));
    assert(!NGShouldRender(0,0,1,1,1,0,1));
    assert(!NGShouldRender(1,1,0,1,1,0,1));
    assert(!NGShouldRender(1,0,1,1,0,0,1));
    assert(!NGShouldRender(1,0,1,1,1,1,1));
    assert(NGShouldRender(1,0,1,1,1,1,0));
    assert(NGIsRecent(1) && !NGIsRecent(60) && !NGIsRecent(-10) && !NGIsRecent(NAN));
    return 0;
}
