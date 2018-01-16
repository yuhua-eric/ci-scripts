#!/bin/bash -e

MAIL_VERSION="Estuary V5.0 - 2018/01/10"
MAIL_TIME=$(date +"%Y/%m/%d")
BUILD_START_TIME=$(date +"%Y/%m/%d %H:%M:%S")
BUILD_END_TIME=$(date +"%Y/%m/%d %H:%M:%S")

export MAIL_TITLE=$(cat <<-END
Estuary CI Auto-test Daily Report(${MAIL_TIME})
END
)

export MAIL_CONTENT_1=$(cat <<-END
        <td style="border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px black">${MAIL_VERSION}</td>
        <td style="border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px black">${BUILD_START_TIME}</td>
        <td style="border: solid 1px #000000">${BUILD_END_TIME}</td>
END
)

export MAIL_CONTENT_2_1=$(cat <<-END
        <td style="border-top: solid 1px #000000;border-left: solid 1px #000000">pass/fail/block/na</td>
        <td style="border-top: solid 1px #000000;border-left: solid 1px #000000"></td>
        <td style="border-top: solid 1px #000000;border-left: solid 1px #000000">xx%</td>
        <td style="text-align: right;justify-content: center;border-top: solid 1px #000000;border-left: solid 1px #000000"><a href="" style="color: #008000">222</a></td>
        <td style="text-align: right;justify-content: center;border-top: solid 1px #000000;border-left: solid 1px #000000"><a href="" style="color: #ff0000">33</a></td>
        <td style="text-align: right;justify-content: center;border-top: solid 1px #000000;border-left: solid 1px #000000;border-right: solid 1px #000000"><a href="" style="color: orange">33</a></td>
END
)

export MAIL_CONTENT_2_2=$(cat <<-END
             <td style="border-top: solid 1px #000000;border-left: solid 1px #000000">pass/fail/block/na</td>
             <td style="border-top: solid 1px #000000;border-left: solid 1px #000000"></td>
             <td style="border-top: solid 1px #000000;border-left: solid 1px #000000">xx%</td>
             <td style="text-align: right;justify-content: center;border-top: solid 1px #000000;border-left: solid 1px #000000"><a href="" style="color: #008000">222</a></td>
             <td style="text-align: right;justify-content: center;border-top: solid 1px #000000;border-left: solid 1px #000000"><a href="" style="color: #ff0000">33</a></td>
             <td style="text-align: right;justify-content: center;border-top: solid 1px #000000;border-left: solid 1px #000000;border-right: solid 1px #000000"><a href="" style="color: orange">33</a></td>
END
)

export MAIL_CONTENT_2_3=$(cat <<-END
        <td style="border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px #000000">pass/fail/block/na</td>
        <td style="border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px #000000"></td>
        <td style="border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px #000000">xx%</td>
        <td style="text-align: right;justify-content: center;border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px #000000"><a href="" style="color: #008000">222</a></td>
        <td style="text-align: right;justify-content: center;border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px #000000"><a href="" style="color: #ff0000">33</a></td>
        <td style="text-align: right;justify-content: center;border: solid 1px #000000"><a href="" style="color: orange">33</a></td>
END
)


export MAIL_CONTENT_3=$(cat <<-END
    <tr style="border-bottom: solid 1px black">
        <td></td>
        <td style="text-align: center;justify-content: center;border-top: solid 1px black;border-left: solid 1px #000000;border-bottom: solid 1px black">kernel</td>
        <td style="text-align: center;justify-content: center;border-top: solid 1px black;border-left: solid 1px #000000;border-bottom: solid 1px black">xxx</td>
        <td style="border-top: solid 1px black;border-left: solid 1px #000000;border-bottom: solid 1px black"></td>
        <td style="border-top: solid 1px black;border-left: solid 1px #000000;border-bottom: solid 1px black"></td>
        <td style="border-top: solid 1px black;border-left: solid 1px #000000;border-bottom: solid 1px black"></td>
        <td style="border-top: solid 1px black;border-left: solid 1px #000000;border-bottom: solid 1px black">xx%</td>
        <td style="text-align: right;justify-content: center;border-top: solid 1px black;border-left: solid 1px #000000;border-bottom: solid 1px black"><a href="" style="color: #008000">222</a></td>
        <td style="text-align: right;justify-content: center;border-top: solid 1px black;border-left: solid 1px #000000;border-bottom: solid 1px black"><a href="" style="color: #ff0000">33</a></td>
        <td style="text-align: right;justify-content: center;border-top: solid 1px black;border-left:solid 1px #000000;border-right: solid 1px #000000;border-bottom: solid 1px black"><a href="" style="color: orange">33</a></td>
    </tr>
END
)

export MAIL_CONTENT_4=$(cat <<-END
             <td style="border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px #000000">Estuary V5.0</td>
             <td style="border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px #000000">xx%</td>
             <td style="border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px #000000">xx%</td>
             <td style="border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px #000000">xx%</td>
             <td style="border: solid 1px #000000">xx%</td>
END
)

export MAIL_CONTENT_5=$(cat <<-END
    <tr>
        <td></td>
             <td style="text-align: center;justify-content: center;border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px black">1</td>
             <td style="text-align: center;justify-content: center;border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px black">1158</td>
             <td style="border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px black">go-bindata</td>
             <td style="border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px black">setup-estuary-repository</td>
             <td style="text-align: center;justify-content: center;border-top: solid 1px #000000;border-left: solid 1px #000000;border-bottom: solid 1px black"></td>
             <td style="text-align: center;justify-content: center;color:#ff0000;border-top: solid 1px #000000;border-left: solid 1px #000000;border-right: solid 1px #000000;border-bottom: solid 1px black"><a href="" style="color: #ff0000">Link</a></td>
    </tr>
END
)

envsubst < mail_template.html > result.html
