#ifndef RAIIEXEC_H
#define RAIIEXEC_H

#include <functional>

class RaiiExec {
public:
    RaiiExec(std::function<void()> func) : m_func(func) {}
    ~RaiiExec() { m_func(); }

private:
    std::function<void()> m_func;
};

#endif // RAIIEXEC_H
