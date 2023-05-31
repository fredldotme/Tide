#ifndef IMEVENTFIXER_H
#define IMEVENTFIXER_H

#include <QObject>

class ImEventFixer : public QObject
{
    Q_OBJECT
public:
    explicit ImEventFixer(QObject *parent = nullptr);

protected:
    bool eventFilter(QObject *obj, QEvent *event) override;
};

#endif // IMEVENTFIXER_H
