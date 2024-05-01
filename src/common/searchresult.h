#ifndef SEARCHRESULT_H
#define SEARCHRESULT_H

#include <QObject>

class SearchResult : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString path MEMBER path NOTIFY pathChanged FINAL)
    Q_PROPERTY(QString name MEMBER name NOTIFY nameChanged FINAL)
    Q_PROPERTY(QString from MEMBER from NOTIFY fromChanged FINAL)
    Q_PROPERTY(int occurances MEMBER occurances NOTIFY occurancesChanged FINAL)

public:
    SearchResult(QObject* parent = nullptr) : QObject(parent) {}

    QString path;
    QString name;
    QString from;
    int occurances;

public slots:
    QString occurance(const int index) {
        for (int i = 0; i < index; i++) {

        }
        return "";
    };

signals:
    void pathChanged();
    void nameChanged();
    void fromChanged();
    void occurancesChanged();
};

#endif // SEARCHRESULT_H
