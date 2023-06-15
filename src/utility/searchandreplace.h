#ifndef SEARCHANDREPLACE_H
#define SEARCHANDREPLACE_H

#include <QObject>

#include "searchresult.h"

class SearchAndReplace : public QObject
{
    Q_OBJECT
public:
    explicit SearchAndReplace(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList suggestions(const QString find, QString sourceRoot);

public slots:
    void replace(const QStringList files, const QString from, const QString to);

signals:

};

#endif // SEARCHANDREPLACE_H
