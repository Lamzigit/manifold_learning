from __future__ import division
from __future__ import absolute_import

from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.utils import check_array

import numpy as np
from scipy import sparse
from scipy.sparse import csr_matrix, spdiags, identity

from utils.graph import create_laplacian, create_adjacency, \
                                     create_feature_mat, maximum, \
                                     compute_adjacency

from utils.eigenvalue_decomposition import EigSolver


class LocalityPreservingProjections(BaseEstimator, TransformerMixin):
    """ Scikit-Learn compatible class for Locality Preserving Projections

    Parameters
    ----------

    n_components : integer, optional, default=2
        number of features for the manifold (=< features of data)

    eig_solver : string ['dense', 'multi', 'sparse'], optional, default='dense'
        eigenvalue solver method

    norm_lap : bool, optional, default=False
        normalized laplacian or not

    tol : float, optional, default=1E-12
        stopping criterion for eigenvalue decomposition of the Laplacian matrix
        when using arpack or multi

    normalization : string ['degree', 'identity'], default = None ('degree')
        normalization parameter for eigenvalue problem

    n_neighbors :

    Attributes
    ----------

    _spectral_embedding :

    _embedding_tuner :


    References
    ----------

    Original Paper:
        http://www.cad.zju.edu.cn/home/xiaofeihe/LPP.html
    Inspired by Dr. Jake Vanderplas' Implementation:
        https://github.com/jakevdp/lpproj

    """
    def __init__(self, n_components=2, eig_solver = 'dense', norm_laplace = False,
                 eigen_tol = 1E-12, regularizer = None,
                 normalization = None, n_neighbors = 2,neighbors_algorithm = 'brute',
                 metric = 'euclidean',n_jobs = 1,weight = 'heat',affinity = None,
                 gamma = 1.0,trees = 10,sparse = True,random_state = 0):
        self.n_components = n_components
        self.eig_solver = eig_solver
        self.regularizer = regularizer
        self.norm_laplace = norm_laplace
        self.eigen_tol = eigen_tol
        self.normalization = normalization
        self.n_neighbors = n_neighbors
        self.neighbors_algorithm = neighbors_algorithm
        self.metric = metric
        self.n_jobs = n_jobs
        self.weight = weight
        self.affinity = affinity
        self.gamma = gamma
        self.trees = trees
        self.sparse = False,
        self.random_state = random_state

    def fit(self, X, y=None):

        # TODO: handle sparse case of data entry
        # check the array
        X = check_array(X)

        # compute the adjacency matrix for X
        W = compute_adjacency(X,
                              n_neighbors=self.n_neighbors,
                              weight=self.weight,
                              affinity=self.affinity,
                              metric=self.metric,
                              neighbors_algorithm=self.neighbors_algorithm,
                              gamma=self.gamma,
                              trees=self.trees,
                              n_jobs=self.n_jobs)

        # compute the projections into the new space
        self.eigVals, self.projection_ = self._spectral_embedding(X, W)

        return self

    def transform(self, X):

        # check the array and see if it satisfies the requirements
        X = check_array(X)
        if self.sparse:
            return X.dot(self.projection_)
        else:
            return np.dot(X, self.projection_)

    def _spectral_embedding(self, X, W):

        # find the eigenvalues and eigenvectors
        return linear_graph_embedding(adjacency=W, data=X,
                                      norm_laplace=self.norm_laplace,
                                      normalization=self.normalization,
                                      eig_solver=self.eig_solver,
                                      eigen_tol=self.eigen_tol)


def linear_graph_embedding(adjacency, data,
                           norm_laplace = None,
                           normalization='degree',
                           n_components=2,
                           eig_solver=None,
                           eigen_tol=1E-12,
                           sparse=True):
    """

    Returns
    -------
    eigenvalues
    eigenvectors
    time elapse

    """
    # create laplacian and diagonal degree matrix
    L, D = create_laplacian(adjacency, norm_lap=norm_laplace)

    #----------------------------
    # tune the eigenvalue problem
    #----------------------------
    # choose which normalization parameter to use
    if normalization in ['degree', 'Degree', None]:
        B = D       # degree normalization

    elif normalization in ['identity']:
        # identity normalization
        B = identity(n=np.shape(L)[0], format='csr')

    else:
        raise ValueError('Not a valid normalization parameter...')

    # create the feature matrices
    A = create_feature_mat(data, L, sparse=sparse)
    B = create_feature_mat(data, B, sparse=sparse)

    #-------------------------------------
    # solve the eigenvalue problem
    #-------------------------------------
    # intialize eigenvalue solver function
    eig_model = EigSolver(n_components=n_components,
                          eig_solver=eig_solver,
                          sparse=sparse,
                          tol=eigen_tol,
                          norm_laplace=norm_laplace)

    # return the eigenvalues and eigenvectors
    return eig_model.find_eig(A=A, B=B)






def swiss_roll_test():

    import matplotlib.pyplot as plt
    plt.style.use('ggplot')

    from time import time

    from sklearn import manifold, datasets
    from sklearn.manifold import SpectralEmbedding
    from lpproj import LocalityPreservingProjection

    n_points = 1000
    X, color = datasets.samples_generator.make_s_curve(n_points,
                                                       random_state=0)
    n_neighbors=20
    n_components=2

    # original lE algorithm


    t0 = time()
    ml_model = SpectralEmbedding(n_neighbors=n_neighbors,
                                 n_components=n_components)
    Y = ml_model.fit_transform(X)
    t1 = time()

    # 2d projection
    fig, ax = plt.subplots(nrows=3, ncols=1, figsize=(5,10))
    ax[0].scatter(Y[:,0], Y[:,1], c=color, label='scikit')
    ax[0].set_title('Sklearn-LE: {t:.2g}'.format(t=t1-t0))


    # Jakes LPP Algorithm

    t0 = time()
    ml_model = LocalityPreservingProjection(n_components=n_components)
    ml_model.fit(X)
    Y = ml_model.transform(X)
    t1 = time()

    ax[1].scatter(Y[:,0], Y[:,1], c=color, label='Jakes Algorithm')
    ax[1].set_title('Jakes LPP: {t:.2g}'.format(t=t1-t0))

    # my SSSE algorith,

    t0 = time()
    ml_model = LocalityPreservingProjections(weight='angle',
                                             n_components=n_components,
                                             n_neighbors=n_neighbors,
                                             sparse=True,
                                             eig_solver='dense')
    ml_model.fit(X)
    Y = ml_model.transform(X)
    t1 = time()

    ax[2].scatter(Y[:,0], Y[:,1], c=color, label='My LPP Algorithm')
    ax[2].set_title('My LPP: {t:.2g}'.format(t=t1-t0))

    plt.show()

if __name__ == "__main__":
    swiss_roll_test()
