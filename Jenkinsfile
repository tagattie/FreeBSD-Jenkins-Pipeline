#! /usr/bin/env groovy

pipeline {
    agent any
    environment {
        // Configuration file (JSON)
        CONFIG='Config.json'
    }
    // parameters {
    // }
    // triggers {
    // }
    stages {
        stage('Read config file and do some preparations.') {
            steps {
                timestamps {
                    script {
                        config = readJSON(file: "${CONFIG}")
                        changed = config.freebsd.branches.collectEntries(
                            {
                                [it, 0]
                            }
                        )
                        echo "changed (initial) = ${changed}"
                        buildable = config.freebsd.branches.collectEntries(
                            {
                                [it, true]
                            }
                        )
                        echo "buildable (initial) = ${buildable}"
                        pollSteps = config.freebsd.branches.collectEntries(
                            {
                                [it, transformIntoPollStep(it)]
                            }
                        )
                        updateSteps = config.freebsd.branches.collectEntries(
                            {
                                [it, transformIntoUpdateStep(it)]
                            }
                        )

                        buildPairs = transformMapListToPairStr(config.freebsd.build)
                        buildWorldSteps = buildPairs.collectEntries(
                            {
                                [it, transformIntoBuildStep(it, 'buildworld')]
                            }
                        )
                        currentBuild.description += ' SUCCESS(config)'
                    }
                }
            }
            post {
                failure {
                    timestamps {
                        script {
                            currentBuild.description += ' FAILURE(config)'
                        }
                    }
                }
            }
        }

        stage('Poll SCM.') {
            when {
                environment name: 'doPoll', value: 'y'
            }
            steps {
                script {
                    parallel(pollSteps)
                }
            }
            post {
                always {
                    echo "changed = ${changed}"
                }
            }
        }

        stage('Update source tree.') {
            when {
                environment name: 'doUpdate', value: 'y'
            }
            steps {
                script {
                    parallel(updateSteps)
                }
            }
            post {
                always {
                    echo "buildable = ${buildable}"
                }
            }
        }

        stage('Build world.') {
            when {
                environment name: 'doBuild', value: 'y'
            }
            steps {
                script {
                    parallel(buildWorldSteps)
                }
            }
        }
    }

    post {
        always {
            timestamps {
                echo "${changed}"
                echo "${buildable}"
            }
        }
    }
}

def transformIntoPollStep(inputStr) {
    return {
        timestamps {
            try {
                changed[inputStr] = sh (
                    returnStdout: true,
                    script: "svnlite status -qu ${config.freebsd.srcDirs."${inputStr}"} | wc -l").trim() as Integer
                currentBuild.description += " SUCCESS(poll ${inputStr} ${changed["${inputStr}"]})"
            } catch (Exception e) {
                currentBuild.description += " FAILURE(poll ${inputStr})"
                throw e
            }
        }
    }
}

def transformIntoUpdateStep(inputStr) {
    return {
        timestamps {
            if (changed[inputStr] > 0) {
                try {
                    sh "sudo svnlite update ${config.freebsd.srcDirs."${inputStr}"}"
                    currentBuild.description += " SUCCESS(update ${inputStr})"
                } catch (Exception e) {
                    buildable[inputStr] = false
                    currentBuild.description += " FAILURE(update ${inputStr})"
                    throw e
                }
            }
        }
    }
}

def transformIntoBuildStep(inputStr, targetStr) {
    return {
        timestamps {
            def branchStr = inputStr.split("-")[0]
            def archStr = inputStr.split("-")[1]
            if ((changed[branchStr] > 0 && buildable[branchStr]) ||
                forceBuild) {
                try {
                    sh """
${WORKSPACE}/Build.sh -n \\
    ${config.freebsd.srcDirs."${branchStr}"} \\
    ${config.freebsd.objDirBase}/"${branchStr}" \\
    ${config.freebsd.archs."${archStr}".arch_m} \\
    ${config.freebsd.archs."${archStr}".arch_p} \\
    ${targetStr}
"""
                    currentBuild.description += " SUCCESS(build ${targetStr}:${inputStr})"
                } catch (Exception e) {
                    currentBuild.description += " FAILURE(build ${targetStr}:${inputStr})"
                    throw e
                }
            }
        }
    }
}

def transformMapListToPairStr(List inputList) {
    def distPairs = []
    Iterator it = inputList.iterator()
    while (it.hasNext()) {
        entry = it.next()
        entry.each(
            { k, v ->
                Iterator it2 = v.iterator()
                while (it2.hasNext()) {
                    element = it2.next()
                    pairstr = k + "-" + element
                    distPairs.add(pairstr)
                }
            }
        )
    }
    return distPairs
}
